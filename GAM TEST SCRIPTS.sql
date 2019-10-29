-------------------------------------------CREATING NON DRIVER TABLE------------------------------------------
--CREATE TABLE FOR dwt12011_aff_cntry_mst
DROP TABLE IF EXISTS public.temp_dwt12011_qa;
CREATE TABLE public.temp_dwt12011_qa
AS
(SELECT cntry_mst.iso_cntry_cd AS iso_cntry_cd,
       cntry_mst.amway_cntry_cd AS amway_cntry_cd,
       cntry_mst.cntry_nm AS cntry_nm,
       cntry_mst.cntry_desc,
       cntry_mst.aff_nm AS aff_nm,
       cntry_mst.rgn_key_no,
       cntry_mst.sub_rgn_key_no,
       cntry_mst.aff_no AS aff_no,
       cntry_mst.dflt_iso_curcy_cd AS dflt_iso_curcy_cd,
       sub_rgn_dim.sub_rgn_desc AS sub_rgn_desc,
       rgn_dim.rgn_desc AS rgn_desc
FROM atomic_legacy.dwt12011_aff_cntry_mst cntry_mst
  LEFT JOIN atomic_legacy.dwt05023_rgn_dim rgn_dim ON cntry_mst.rgn_key_no = rgn_dim.rgn_key_no
  LEFT JOIN atomic_legacy.dwt05024_sub_rgn_dim sub_rgn_dim ON sub_rgn_dim.sub_rgn_key_no = cntry_mst.sub_rgn_key_no);

---------------***************************************-------------------

--CREATE TABLE FOR 41151_ACCOUNT_PARTY_CNTRC
DROP TABLE IF EXISTS public.qa_dwt41151_account_party_cntrc;
CREATE TABLE public.qa_dwt41151_account_party_cntrc
AS
(
  SELECT ndt_account_party_cntrc.aff AS aff,
         ndt_account_party_cntrc.abo_number AS abo_number,
         MAX(ndt_account_party_cntrc.sign_date::DATE) AS sign_date
  FROM  atomic_legacy.dwt41151_account_party_cntrc ndt_account_party_cntrc
  GROUP BY 1,2
);

---------------***************************************-------------------

--CREATE TABLE FOR dwt41036_ddatbat
DROP TABLE IF EXISTS PUBLIC.dwt41036_ddatbat_qa;
CREATE TABLE PUBLIC.dwt41036_ddatbat_qa
DISTSTYLE ALL
SORTKEY(intgrt_ctl_aff,distb_nbr)
AS
SELECT MIN(db_dt)::VARCHAR(8)::DATE AS db_dt, LPAD(intgrt_ctl_aff,'3','0') AS intgrt_ctl_aff, distb_nbr
FROM atomic_legacy.dwt41036_ddatbat
WHERE AUDIT_TYPE_CD = 'CRV'
GROUP BY 2,3;

SELECT COUNT(*)
FROM PUBLIC.dwt41036_ddatbat_qa;  --669747

---------------****************--------------------

--CREATE TABLE FOR dwt41036_ddatbat_renewal
DROP TABLE IF EXISTS public.dwt41036_ddatbat_renewal_qa;
CREATE TABLE public.dwt41036_ddatbat_renewal_qa
SORTKEY(intgrt_ctl_aff,distb_nbr)
AS
SELECT MAX(db_dt)::VARCHAR(8)::DATE AS db_dt, LPAD(intgrt_ctl_aff,'3','0') AS intgrt_ctl_aff, distb_nbr
FROM atomic_legacy.dwt41036_ddatbat
WHERE AUDIT_TYPE_CD IN ('R','G','H','RQ')
AND db_dt >= 20100101
GROUP BY 2,3;

------------------******************--------------------

--CREATE TABLE FOR dwt41064_imc_service_contracts
DROP TABLE IF EXISTS public.dwt41064_imc_service_contracts_renewal_qa;
CREATE TABLE public.dwt41064_imc_service_contracts_renewal_qa
DISTSTYLE ALL
SORTKEY(intgrt_aff_cd,imc_no)
AS
SELECT MAX(ord_dt)::DATE AS ord_dt, LPAD(intgrt_aff_cd,'3','0') AS intgrt_aff_cd, imc_no
FROM atomic_legacy.dwt41064_imc_service_contracts
WHERE ln_type ='SERVICE'
  AND inventory_item_id IN(1029,1030,1031,1035,1036,1037,1041,1042,1043,1052,1053,1056,1058,1059,1062,1063,1064,1065)
  AND sts_cd IN('ACTIVE','SIGNED')
  AND ord_dt >= 20100101
GROUP BY 2,3;

------------------********************-------------------

DROP TABLE IF EXISTS public.imc_dim_qa;
CREATE TABLE public.imc_dim_qa
AS
(SELECT * from atomic_legacy.dwt01021_imc_master_dim imc where imc.appl_dt_key_no <> '19000101')

------------------********************-------------------

DROP TABLE IF EXISTS public.qa_dwt40000_acct_hist_mdms;
CREATE TABLE public.qa_dwt40000_acct_hist_mdms
AS
(
  SELECT  acct_hist_mdms.aff_no AS aff_no,
          acct_hist_mdms.ibo_no AS ibo_no,
          MAX(acct_hist_mdms.proc_dt) AS proc_dt
  FROM atomic.dwt40000_acct_hist_mdms acct_hist_mdms
  WHERE acct_hist_mdms.proc_cd IN ('RN','RX')
  GROUP BY 1,2
);

--------------------------------------------1. CHECK COUNTS---------------------------------------------------------------------

--GAM COUNT
SELECT COUNT(*) FROM curated_integration.global_account_master; -- 92106732
--SG_GAM COUNT
SELECT COUNT(*) FROM surrogate.sg_global_account_master; -- 92562743


---- ROWS that must came into gam

-- MDMS
SELECT COUNT(*)
FROM atomic.dwt41141_account_dtl WHERE business_entity_code <> ''; -- 1792557

-- LEGACY
SELECT COUNT(*)
FROM atomic_legacy.dwt41042_distb_dtl legacy
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT ( LPAD( legacy.affiliate_code,'3','0'), legacy.abo_no) = CONCAT ( LPAD( mdms.affiliate_code,'3','0'), mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND TRIM(legacy.business_entity_code) <> '';  -- 82124129

-- ATLAS
SELECT COUNT(*)
FROM atomic_legacy.dwt40016_imc atlas
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''; -- 1109273

--TOTAL
SELECT 8875996 + 82124129 + 1109273; -- 92109398


---- In actual rows came into gam

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> '';  --8875996

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT ( LPAD( legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR mdms.business_entity_code = '')
AND   TRIM(legacy.Business_Entity_Code) <> '';  --90338536

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON gam.global_account_id = atlas.imc_number
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''; -- 1109273

--TOTAL
SELECT 8875996 + 82124129 + 1109273; -- 92109398


----------------------------------------------------------2. CHECK DUPLICATES FOR DRIVER TABLES---------------------------------
--MDMS
SELECT LPAD(mdms.affiliate_code,'3','0'),
       mdms.abo_no,
       COUNT(*)
FROM atomic.dwt41141_account_dtl mdms
WHERE mdms.business_entity_code <> ''
GROUP BY 1,2
HAVING COUNT(*) > 1 LIMIT 10;  -- 0

SELECT COUNT(*)
FROM atomic.dwt41141_account_dtl
WHERE length(trim(affiliate_code))<3;  --0

--LEGACY
SELECT LPAD(legacy.affiliate_code,'3','0'),
       legacy.abo_no,
       COUNT(*)
FROM atomic_legacy.dwt41042_distb_dtl legacy
WHERE legacy.Business_Entity_Code <> ''
GROUP BY 1,2
HAVING COUNT(*) > 1 LIMIT 10;  --0 

SELECT COUNT(*)
FROM atomic_legacy.dwt41042_distb_dtl
WHERE length(trim(affiliate_code))<3;  --0

--ATLAS
SELECT LPAD(atlas.imc_number,'3','0'),
       COUNT(*)
FROM atomic_legacy.dwt40016_imc atlas
JOIN public.temp_dwt12011_qa temp ON atlas.home_country = temp.iso_cntry_cd
WHERE atlas.imc_type <> 'INTERCOMPANY'
AND   temp.amway_cntry_cd <> ''
GROUP BY atlas.imc_number
HAVING COUNT(*) > 1 LIMIT 10;  --0

--GAM PK
SELECT global_account_wid, source_name,
       COUNT(*)
FROM curated_integration.global_account_master
GROUP BY 1,2
HAVING COUNT(*) > 1 LIMIT 100; -- FOUNT DUPLICATES

--GAM NK
SELECT global_account_id, source_name,
       COUNT(*)
FROM curated_integration.global_account_master
GROUP BY 1,2
HAVING COUNT(*) > 1 LIMIT 20; -- FOUND DUPLICATES

SELECT COUNT(*)
FROM curated_integration.global_account_master
WHERE LENGTH(TRIM(affiliate_code))<3;  --0

--SG_GAM PK
SELECT global_account_wid,
       COUNT(*)
FROM surrogate.sg_global_account_master
GROUP BY 1
HAVING COUNT(*) > 1 limit 10;  --0

--SG_GAM NK
SELECT CONCAT(affiliate_code,abo_number),
       COUNT(*)
FROM surrogate.sg_global_account_master
GROUP BY 1
HAVING COUNT(*) > 1 limit 10;  --0

SELECT COUNT(*)
FROM surrogate.sg_global_account_master
WHERE length(trim(affiliate_code))<3;

SELECT affiliate_code
FROM surrogate.sg_global_account_master
WHERE length(trim(affiliate_code))<3;


---------------------------------------------------------------------(3) SG DIM TESTING -------------------------------------------------------
--MDMS
SELECT COUNT(*)
FROM atomic.dwt41141_account_dtl mdms
  JOIN surrogate.sg_global_account_master sg_gam
    ON mdms.abo_no = sg_gam.abo_number
   AND LPAD (mdms.affiliate_code,'3','0') = sg_gam.affiliate_code
WHERE mdms.business_entity_code <> '';  -- 8874962

--LEGACY
SELECT COUNT(*)
FROM atomic_legacy.dwt41042_distb_dtl legacy
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	JOIN surrogate.sg_global_account_master sg_gam
    ON legacy.abo_no = sg_gam.abo_number
   AND LPAD (legacy.affiliate_code,'3','0') = sg_gam.affiliate_code
   LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD( legacy.affiliate_code,'3','0'), legacy.abo_no) = CONCAT (LPAD( mdms.affiliate_code,'3','0'), mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '';  -- 82122497

--ATLAS
SELECT COUNT(*) FROM surrogate.sg_global_account_master sgam
    JOIN atomic_legacy.dwt40016_imc atlas
        ON sgam.affiliate_code = SUBSTRING(atlas.imc_number,1,3) AND sgam.abo_number = SUBSTRING(atlas.imc_number,4)::BIGINT
    JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
    LEFT JOIN (SELECT distb.affiliate_code, distb.business_entity_code, distb.abo_no
                FROM atomic_legacy.dwt41042_distb_dtl distb
                JOIN atomic.wwt01020_aff_mst am_valid_aff
        ON am_valid_aff.aff_id = CASE WHEN TRIM(distb.affiliate_code) = '' THEN 0    ELSE distb.affiliate_code::SMALLINT END
    ) legacy
        ON atlas.imc_number = CONCAT(LPAD( legacy.affiliate_code,3,'0'),legacy.abo_no)
    LEFT JOIN atomic.dwt41141_account_dtl mdms
        ON atlas.imc_number = CONCAT(LPAD( mdms.affiliate_code,3,'0'),mdms.abo_no)
    WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
        AND (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
        AND TRIM(atlas.imc_type) <> 'INTERCOMPANY' AND TRIM(tmp.amway_cntry_cd) <> '';  --1109273
 
SELECT 8874962 + 82122497 + 1109273;  --92106732

---------------------------------------------------4. FIELD BY FIELD TESTING----------------------------------------  91486527
-- 1. global_account_wid

--MUST BE A NUMBER (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam WHERE gam.global_account_wid ~ '^[0-9]+$' = 'TRUE';  --91486280

--MUST BE UNIQUE (QR)
SELECT COUNT(*),
       gam.global_account_wid
FROM curated_integration.global_account_master gam
GROUP BY 2
HAVING COUNT(*) > 1 LIMIT 10;

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN surrogate.sg_global_account_master sg_gam ON gam.affiliate_code = sg_gam.affiliate_code AND gam.abo_number = sg_gam.abo_number
  WHERE sg_gam.global_account_wid = gam.global_account_wid; -- 91703017
  
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN surrogate.sg_global_account_master sg_gam ON gam.global_account_id = CONCAT(sg_gam.affiliate_code,sg_gam.abo_number)
  WHERE sg_gam.global_account_wid = gam.global_account_wid; -- 91703006
  
-- 2. global_account_id

--MUST BE A NUMBER (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam WHERE gam.global_account_id ~ '^[0-9]+$' = 'TRUE';  --91486521

--MUST BE UNIQUE (QR)
SELECT COUNT(*),
       gam.global_account_id
FROM curated_integration.global_account_master gam
GROUP BY 2
HAVING COUNT(*) > 1 LIMIT 10;

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> '';  -- 1783355

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''; -- 89742352

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''; -- 1087477

--3 account_id

--MUST NOT START AND END WITH SPACE (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam WHERE substring(gam.account_id,1,1) <> ' ' AND substring(gam.account_id,LENGTH(gam.account_id) ,1) <> ' ';   --91486527

--MUST BE UNIQUE (QR)
SELECT COUNT(*), gam.account_id
FROM curated_integration.global_account_master gam
GROUP BY 2 HAVING(COUNT(*)) > 1 LIMIT 20;   --FOUND DUPLICATES

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.account_id IS NULL;

--SPECIAL CHARACTERS ARE NOT ALLOWED (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.account_id ~ '^[0-9]+$' = 'TRUE';  --91486527

--MDMS

--MUST BE UNIQUE (QR)
SELECT COUNT(*), gam.account_id
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> '' AND gam.account_id = mdms.account_id GROUP BY 2 HAVING (COUNT(*)) > 1 LIMIT 10;  --FOUND DUPLICATES

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> '' AND gam.account_id = mdms.account_id;  -- 1783355

--LEGACY

--MUST BE UNIQUE (QR)
SELECT COUNT(*), gam.account_id
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '' AND gam.account_id = legacy.abo_no GROUP BY 2 HAVING (COUNT(*)) > 1 LIMIT 10;  --FOUND DUPLICATES

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '' AND gam.account_id = legacy.abo_no; -- 89742352

--ATLAS

--MUST BE UNIQUE (QR)
SELECT COUNT(*), gam.account_id
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.account_id = SUBSTRING(atlas.imc_number,4)::BIGINT GROUP BY 2 HAVING (COUNT(*)) > 1 LIMIT 10;  --FOUND DUPLICATES

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.account_id = SUBSTRING(atlas.imc_number,4)::BIGINT; -- 1087477

-- 4. abo_number

--MUST NOT START AND END WITH SPACE (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam WHERE substring(gam.abo_number,1,1) <> ' ' AND substring(gam.abo_number,LENGTH(gam.abo_number) ,1) <> ' ';   --91486527

--MUST BE UNIQUE (QR)
SELECT COUNT(*), gam.abo_number
FROM curated_integration.global_account_master gam
GROUP BY 2 HAVING(COUNT(*)) > 1 LIMIT 20;   --FOUND DUPLICATES

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.abo_number IS NULL;

--SPECIAL CHARACTERS ARE NOT ALLOWED (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.abo_number ~ '^[0-9]+$' = 'TRUE';  --91486527

--MDMS

--MUST BE UNIQUE (QR)
SELECT COUNT(*), gam.abo_number
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> '' AND gam.abo_number = mdms.abo_no
GROUP BY 2 HAVING(COUNT(*)) > 1 LIMIT 20;   --FOUND DUPLICATES

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> '' AND gam.abo_number = mdms.abo_no;  -- 1783355

--LEGACY

--MUST BE UNIQUE (QR)
SELECT COUNT(*), gam.abo_number
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '' AND gam.abo_number = legacy.abo_no
GROUP BY 2 HAVING(COUNT(*)) > 1 LIMIT 20;   --FOUND DUPLICATES

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '' AND gam.abo_number = legacy.abo_no; -- 88814043

--ATLAS

--MUST BE UNIQUE (QR)
SELECT COUNT(*), gam.abo_number
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.abo_number = SUBSTRING(atlas.imc_number,4)::BIGINT
GROUP BY 2 HAVING(COUNT(*)) > 1 LIMIT 20;   --FOUND DUPLICATES

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.abo_number = SUBSTRING(atlas.imc_number,4)::BIGINT; -- 1089303

-- 5. affiliate_code

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.affiliate_code IS NULL OR gam.affiliate_code = '';  --0

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> '' AND gam.affiliate_code = LPAD(mdms.affiliate_code,'3','0');  -- 1783355

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR mdms.business_entity_code = '')
AND   legacy.Business_Entity_Code <> '' AND gam.affiliate_code = LPAD(legacy.affiliate_code,'3','0'); -- 88814043

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.affiliate_code = NVL(atlas.intgrt_aff_cd, atlas.sales_plan_affiliate); -- 1089303

-- 6. affiliate_name

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.affiliate_name IS NULL OR gam.affiliate_name = '';  --0

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt12011_aff_cntry_mst ndt_aff_cntry_mst ON LPAD (mdms.business_entity_code,'3','0') = ndt_aff_cntry_mst.amway_cntry_cd
WHERE mdms.business_entity_code <> ''
AND   gam.affiliate_name = ndt_aff_cntry_mst.aff_desc;  -- 604480

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic_legacy.dwt12011_aff_cntry_mst ndt_aff_cntry_mst ON legacy.business_entity_code = ndt_aff_cntry_mst.amway_cntry_cd
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR mdms.business_entity_code = '')
AND   legacy.Business_Entity_Code <> '' AND gam.affiliate_name = ndt_aff_cntry_mst.aff_desc; -- 89792741

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt12011_aff_cntry_mst ndt_aff_cntry_mst ON atlas.home_country = ndt_aff_cntry_mst.iso_cntry_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.affiliate_name = ndt_aff_cntry_mst.aff_nm; -- 1089303

--7. business_entity_code

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.business_entity_code IS NULL OR gam.business_entity_code = '';  --0

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.business_entity_code = LPAD(mdms.business_entity_code,'3','0');  --604480

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '' AND gam.business_entity_code = LPAD( legacy.business_entity_code,'3','0'); --89742352

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.business_entity_code = tmp.amway_cntry_cd;  --1089303

--8. country_name

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.country_name IS NULL OR gam.country_name = '';  --0

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt12011_aff_cntry_mst ndt_aff_cntry_mst ON LPAD (mdms.business_entity_code,'3','0') = ndt_aff_cntry_mst.amway_cntry_cd
WHERE mdms.business_entity_code <> ''
AND   gam.country_name = ndt_aff_cntry_mst.cntry_nm;  --604480

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt12011_aff_cntry_mst ndt_aff_cntry_mst ON LPAD (legacy.business_entity_code,'3','0') = ndt_aff_cntry_mst.amway_cntry_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '' AND gam.country_name =  ndt_aff_cntry_mst.cntry_nm;  --89742352

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt12011_aff_cntry_mst ndt_aff_cntry_mst ON atlas.home_country = ndt_aff_cntry_mst.iso_cntry_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.country_name = ndt_aff_cntry_mst.cntry_nm;  --1087477

--9. region

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.region IS NULL OR gam.region = '';

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt12011_aff_cntry_mst ndt_aff_cntry_mst ON LPAD (mdms.business_entity_code,'3','0') = ndt_aff_cntry_mst.amway_cntry_cd
  JOIN atomic_legacy.dwt05023_rgn_dim ndt_rgn_dim ON ndt_aff_cntry_mst.rgn_key_no = ndt_rgn_dim.rgn_key_no
WHERE mdms.business_entity_code <> ''
AND   gam.region = ndt_rgn_dim.rgn_desc;  --604480

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt12011_aff_cntry_mst ndt_aff_cntry_mst ON LPAD (legacy.business_entity_code,'3','0') = ndt_aff_cntry_mst.amway_cntry_cd
  JOIN atomic_legacy.dwt05023_rgn_dim ndt_rgn_dim ON ndt_aff_cntry_mst.rgn_key_no = ndt_rgn_dim.rgn_key_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '' AND gam.region =  ndt_rgn_dim.rgn_desc;  --89742352

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt12011_aff_cntry_mst ndt_aff_cntry_mst ON atlas.home_country = ndt_aff_cntry_mst.iso_cntry_cd
  JOIN atomic_legacy.dwt05023_rgn_dim ndt_rgn_dim ON ndt_aff_cntry_mst.rgn_key_no = ndt_rgn_dim.rgn_key_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.region = ndt_rgn_dim.rgn_desc;  --1087477

--10. sub_region

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.sub_region IS NULL OR gam.sub_region = '';  --0

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt12011_aff_cntry_mst ndt_aff_cntry_mst ON LPAD (mdms.business_entity_code,'3','0') = ndt_aff_cntry_mst.amway_cntry_cd
  JOIN atomic_legacy.dwt05024_sub_rgn_dim ndt_sub_rgn_dim ON ndt_aff_cntry_mst.sub_rgn_key_no = ndt_sub_rgn_dim.sub_rgn_key_no
WHERE mdms.business_entity_code <> ''
AND   gam.sub_region = ndt_sub_rgn_dim.sub_rgn_desc;  --604480

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt12011_aff_cntry_mst ndt_aff_cntry_mst ON LPAD (legacy.business_entity_code,'3','0') = ndt_aff_cntry_mst.amway_cntry_cd
  JOIN atomic_legacy.dwt05024_sub_rgn_dim ndt_sub_rgn_dim ON ndt_aff_cntry_mst.sub_rgn_key_no = ndt_sub_rgn_dim.sub_rgn_key_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   gam.sub_region = ndt_sub_rgn_dim.sub_rgn_desc;  --89742352

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt12011_aff_cntry_mst ndt_aff_cntry_mst ON atlas.home_country = ndt_aff_cntry_mst.iso_cntry_cd
  JOIN atomic_legacy.dwt05023_rgn_dim ndt_rgn_dim ON ndt_aff_cntry_mst.rgn_key_no = ndt_rgn_dim.rgn_key_no
  JOIN atomic_legacy.dwt05024_sub_rgn_dim ndt_sub_rgn_dim ON ndt_aff_cntry_mst.sub_rgn_key_no = ndt_sub_rgn_dim.sub_rgn_key_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.sub_region = ndt_sub_rgn_dim.sub_rgn_desc;  --1087477

--11. iso_currency_code

--MUST BE UPPER CASE (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.iso_currency_code = UPPER( gam.iso_currency_code);  --91486527

--Must be exactly 3 characters long (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.iso_currency_code <> '' AND LENGTH( gam.iso_currency_code) < 3;  --91468368

--MUST BE ALL LETTERS (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.iso_currency_code <> '' AND gam.iso_currency_code ~ '^[A-Z]+$' = 'TRUE';  --56732862

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.iso_currency_code = mdms.iso_currency_code;  --604480

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '' 
AND   gam.iso_currency_code = legacy.iso_currency_code;  --89742352

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt12011_aff_cntry_mst ndt_aff_cntry_mst ON atlas.home_country = ndt_aff_cntry_mst.iso_cntry_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.iso_currency_code = ndt_aff_cntry_mst.dflt_iso_curcy_cd;  --1087477

--12. language_code

--MUST BE LOWER CASE (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam WHERE gam.language_code = LOWER (gam.language_code);

--MUST BE 2 CHARACTERS LONG (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam WHERE LENGTH( gam.language_code) < 2;

--MUST BE ALL LETTERS (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam WHERE gam.language_code ~ '^[A-Z]+$' = 'TRUE';

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> '' AND gam.language_code = LOWER(mdms.language_code);  --604436

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN common_dims.w_country_dim ndt_country_dim ON LPAD(mdms.business_entity_code,3,'0') = ndt_country_dim.amway_country_code
WHERE mdms.business_entity_code <> '' AND (mdms.language_code = '' OR mdms.language_code IS NULL) AND gam.language_code = LOWER(ndt_country_dim.default_iso_language_code);  --45

SELECT 604436 + 45; --604481

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT ( LPAD( legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic_legacy.dwt41048_dlngdta ndt_dwt41048_dlngdta ON LOWER( legacy.language_code) = LOWER( ndt_dwt41048_dlngdta.lang_cd) AND legacy.country_code = ndt_dwt41048_dlngdta.intgrt_cntry_cd
WHERE (mdms.affiliate_code IS NULL OR mdms.business_entity_code = '')
AND   TRIM(legacy.Business_Entity_Code) <> '' AND gam.language_code = LOWER( ndt_dwt41048_dlngdta.iso_lang_cd);   --89693247

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT ( LPAD( legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
	LEFT JOIN atomic_legacy.dwt41048_dlngdta ndt_dwt41048_dlngdta ON LOWER( legacy.language_code) = LOWER( ndt_dwt41048_dlngdta.lang_cd) AND legacy.country_code = ndt_dwt41048_dlngdta.intgrt_cntry_cd
	JOIN common_dims.w_country_dim ndt_country_dim ON LPAD(legacy.business_entity_code,3,'0') = ndt_country_dim.amway_country_code
WHERE (mdms.affiliate_code IS NULL OR mdms.business_entity_code = '')
AND   TRIM(legacy.Business_Entity_Code) <> '' AND ndt_dwt41048_dlngdta.iso_lang_cd IS NULL AND gam.language_code = LOWER( ndt_country_dim.default_iso_language_code);  --99495

select 89693247 + 99495;  --89792742


--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON gam.global_account_id = atlas.imc_number
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt40011_imc_applicants ndt_dwt40011_imc_applicants 
        ON atlas.imc_number = ndt_dwt40011_imc_applicants.imc_number
        AND atlas.intgrt_aff_cd = ndt_dwt40011_imc_applicants.intgrt_aff_cd
        AND UPPER (ndt_dwt40011_imc_applicants.contact_type) = 'APPLICANT1'
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.language_code = LOWER (ndt_dwt40011_imc_applicants.preferred_language); -- 1082635

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON gam.global_account_id = atlas.imc_number
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt40011_imc_applicants ndt_dwt40011_imc_applicants
    ON atlas.imc_number = ndt_dwt40011_imc_applicants.imc_number
    AND atlas.intgrt_aff_cd = ndt_dwt40011_imc_applicants.intgrt_aff_cd
    AND UPPER (ndt_dwt40011_imc_applicants.contact_type) = 'APPLICANT1'
  JOIN common_dims.w_country_dim ndt_country_dim ON tmp.amway_cntry_cd = ndt_country_dim.amway_country_code
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   (ndt_dwt40011_imc_applicants.preferred_language IS NULL OR ndt_dwt40011_imc_applicants.preferred_language = '')
AND   gam.language_code = LOWER( ndt_country_dim.default_iso_language_code);  --655

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON gam.global_account_id = atlas.imc_number
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  LEFT JOIN atomic_legacy.dwt40011_imc_applicants ndt_dwt40011_imc_applicants 
        ON atlas.imc_number = ndt_dwt40011_imc_applicants.imc_number
        AND atlas.intgrt_aff_cd = ndt_dwt40011_imc_applicants.intgrt_aff_cd
        AND UPPER (ndt_dwt40011_imc_applicants.contact_type) = 'APPLICANT1'
  JOIN common_dims.w_country_dim ndt_country_dim ON tmp.amway_cntry_cd = ndt_country_dim.amway_country_code
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND ndt_dwt40011_imc_applicants.imc_number IS NULL AND gam.language_code = LOWER( ndt_country_dim.default_iso_language_code);  --4187


SELECT 1082635 + 655 + 4187;  --1087477

--13. signed_contract_date

--MDMS  1673641
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.qa_dwt41151_account_party_cntrc ndt_account_party_cntrc 
    ON LPAD(mdms.affiliate_code,3,'0') = LPAD(ndt_account_party_cntrc.aff,3,'0')
    AND mdms.abo_no = ndt_account_party_cntrc.abo_number
WHERE mdms.business_entity_code <> ''
AND   gam.signed_contract_date = ndt_account_party_cntrc.sign_date::DATE;  --1242

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.qa_dwt41151_account_party_cntrc ndt_account_party_cntrc 
    ON LPAD(mdms.affiliate_code,3,'0') = LPAD(ndt_account_party_cntrc.aff,3,'0')
    AND mdms.abo_no = ndt_account_party_cntrc.abo_number
WHERE mdms.business_entity_code <> ''  --1272
AND   (ndt_account_party_cntrc.sign_date IS NULL OR TRIM(ndt_account_party_cntrc.sign_date) = '')
AND   gam.signed_contract_date = '19000101'::DATE;  --30

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.qa_dwt41151_account_party_cntrc ndt_account_party_cntrc 
    ON LPAD(mdms.affiliate_code,3,'0') = LPAD(ndt_account_party_cntrc.aff,3,'0')
    AND mdms.abo_no = ndt_account_party_cntrc.abo_number
WHERE mdms.business_entity_code <> ''
AND   gam.signed_contract_date <> ndt_account_party_cntrc.sign_date::DATE;  --0

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN public.qa_dwt41151_account_party_cntrc ndt_account_party_cntrc 
    ON LPAD(mdms.affiliate_code,3,'0') = ndt_account_party_cntrc.aff
    AND mdms.abo_no = ndt_account_party_cntrc.abo_number
WHERE mdms.business_entity_code <> ''
AND   ndt_account_party_cntrc.aff IS NULL
AND   gam.signed_contract_date = '19000101'::DATE;  --1672369

SELECT 1242 + 30 + 1672369;  --1673641

--LEGACY    --89648859
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.dwt41036_ddatbat_qa ndt_ddatbat_qa ON ndt_ddatbat_qa.intgrt_ctl_aff = LPAD(legacy.affiliate_code,'3','0') AND ndt_ddatbat_qa.distb_nbr = legacy.abo_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND gam.signed_contract_date = ndt_ddatbat_qa.db_dt::DATE;  --254461

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN public.dwt41036_ddatbat_qa ndt_ddatbat_qa ON ndt_ddatbat_qa.intgrt_ctl_aff = LPAD(legacy.affiliate_code,'3','0') AND ndt_ddatbat_qa.distb_nbr = legacy.abo_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND ndt_ddatbat_qa.intgrt_ctl_aff IS NULL AND gam.signed_contract_date = '19000101'::DATE; -- 89394398

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN public.dwt41036_ddatbat_qa ndt_ddatbat_qa ON ndt_ddatbat_qa.intgrt_ctl_aff = LPAD(legacy.affiliate_code,'3','0') AND ndt_ddatbat_qa.distb_nbr = legacy.abo_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND ndt_ddatbat_qa.intgrt_ctl_aff IS NULL AND gam.signed_contract_date <> '19000101'::DATE; -- 0

SELECT 254461 + 89394398 + 0; -- 89648859

--ATLAS   592724
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   TRIM(atlas.signed_form_received_date) <> ''
AND   atlas.signed_form_received_date IS NOT NULL
AND gam.signed_contract_date = atlas.signed_form_received_date::DATE;  --442420

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   (TRIM(atlas.signed_form_received_date) = '' OR atlas.signed_form_received_date IS NULL)
AND   gam.signed_contract_date = '19000101'::DATE;  --150304

SELECT 442420 + 150304;  --592724


--14. expiration_date                  ----------------------------------------------NEED TO REVIEW

--MDMS
SELECT COUNT(*) 
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.expiration_date = 
CASE
   --WHEN ENTRY DATE IS NULL THEN THERE SHOULD BE DEFAULT VALUE FOR DATE
   WHEN (mdms.expiration_date IS NULL OR mdms.expiration_date::VARCHAR = '') THEN '19000101'::DATE
   --WHEN MONTH IS DECEMBER AND DAY IS GREATER THAN 31
   WHEN (SUBSTRING(mdms.expiration_date,6,2)::INT = 12 AND SUBSTRING(mdms.expiration_date,9,2)::INT > 31) THEN (SUBSTRING(mdms.expiration_date,1,4)::INT + 1 || '01' || '01')::DATE
   --WHEN DAY IS GREATER THAN 31
   WHEN SUBSTRING(mdms.expiration_date,9,2)::INT > 31 THEN (SUBSTRING(mdms.expiration_date,1,4) || (SUBSTRING(mdms.expiration_date,6,2)::INT +1) || '01')::DATE
   --WHEN MONTHS ARE APRIL, JUNE, SEPTEMBER, NOVEMBER AND DAY IS GRETAER THAN 30
   WHEN (SUBSTRING(mdms.expiration_date,6,2)::INT IN (04,06,09,11) AND SUBSTRING(mdms.expiration_date,9,2)::INT > 30) THEN (SUBSTRING(mdms.expiration_date,1,4) || (SUBSTRING(mdms.expiration_date,6,2)::INT +1) || '01')::DATE
   --WHEN NOT A LEAP YEAR AND MONTH IS FEBUARY AND DAY IS GREATER THAN 28
   WHEN (SUBSTRING(mdms.expiration_date,1,4)::INT % 4 <> 0 AND SUBSTRING(mdms.expiration_date,6,2)::INT = 02 AND SUBSTRING(mdms.expiration_date,9,2)::INT > 28) THEN (SUBSTRING(mdms.expiration_date,1,4) || (SUBSTRING(mdms.expiration_date,6,2)::INT +1) || '01')::DATE
   --WHEN LEAP YEAR, MONTH IS FEBUARY AND DAY IS GREATER THAN 29
   WHEN (SUBSTRING(mdms.expiration_date,1,4)::INT % 4 = 0 AND SUBSTRING(mdms.expiration_date,6,2)::INT = 02 AND SUBSTRING(mdms.expiration_date,9,2)::INT > 29) THEN (SUBSTRING(mdms.expiration_date,1,4) || (SUBSTRING(mdms.expiration_date,6,2)::INT +1) || '01')::DATE
   ELSE
   mdms.expiration_date::DATE
END;  --609526

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy 
  ON LPAD(legacy.affiliate_code,3,'0') <> '010'
  AND gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND gam.expiration_date = 
CASE
   --WHEN ENTRY DATE IS NULL THEN THERE SHOULD BE DEFAULT VALUE FOR DATE
   WHEN (TRIM(legacy.expiration_date) = '' OR legacy.expiration_date IS NULL) THEN '19000101'::DATE
   --WHEN MONTH IS DECEMBER AND DAY IS GREATER THAN 31
   WHEN (SUBSTRING(legacy.expiration_date,5,2)::INT = 12 AND SUBSTRING(legacy.expiration_date,7,2)::INT > 31) THEN ((SUBSTRING(legacy.expiration_date,1,4)::INT + 1)::VARCHAR || '01' || '01')::DATE
   --WHEN DAY IS GREATER THAN 31
   WHEN SUBSTRING(legacy.expiration_date,7,2)::INT > 31 THEN (SUBSTRING(legacy.expiration_date,1,4) || (SUBSTRING(legacy.expiration_date,5,2)::INT +1)::VARCHAR || '01')::DATE
   --WHEN MONTHS ARE APRIL, JUNE, SEPTEMBER, NOVEMBER AND DAY IS GRETAER THAN 30
   WHEN (SUBSTRING(legacy.expiration_date,5,2)::INT IN (04,06,09,11) AND SUBSTRING(legacy.expiration_date,7,2)::INT > 30) THEN (SUBSTRING(legacy.expiration_date,1,4) || (SUBSTRING(legacy.expiration_date,5,2)::INT +1)::VARCHAR || '01')::DATE
   --WHEN NOT A LEAP YEAR AND MONTH IS FEBUARY AND DAY IS GREATER THAN 28
   WHEN (SUBSTRING(legacy.expiration_date,1,4)::INT % 4 <> 0 AND SUBSTRING(legacy.expiration_date,5,2)::INT = 02 AND SUBSTRING(legacy.expiration_date,7,2)::INT > 28) THEN (SUBSTRING(legacy.expiration_date,1,4) || (SUBSTRING(legacy.expiration_date,5,2)::INT +1)::VARCHAR || '01')::DATE
   --WHEN LEAP YEAR, MONTH IS FEBUARY AND DAY IS GREATER THAN 29
   WHEN (SUBSTRING(legacy.expiration_date,1,4)::INT % 4 = 0 AND SUBSTRING(legacy.expiration_date,5,2)::INT = 02 AND SUBSTRING(legacy.expiration_date,7,2)::INT > 29) THEN (SUBSTRING(legacy.expiration_date,1,4) || (SUBSTRING(legacy.expiration_date,5,2)::INT +1)::VARCHAR || '01')::DATE
   ELSE
--   '19000101'
   legacy.expiration_date::DATE
END  --604481

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic_legacy.dwt41041_dimcprf ndt_dimcprf 
	ON lpad(legacy.Affiliate_Code, 3, '0') = '010'
        AND LPAD(ndt_dimcprf.intgrt_ctl_aff, 3, '0') = lpad(legacy.affiliate_code, 3, '0')
        AND ndt_dimcprf.distb_nbr = legacy.abo_no
        AND TRIM (legacy.prime_co) = ndt_dimcprf.db_co
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   gam.affiliate_code = 010
AND gam.expiration_date = 
CASE
   --WHEN ENTRY DATE IS NULL THEN THERE SHOULD BE DEFAULT VALUE FOR DATE
   WHEN (ndt_dimcprf.db_exp_date IS NULL OR ndt_dimcprf.db_exp_date = '') THEN '19000101'::DATE
   --WHEN MONTH IS DECEMBER AND DAY IS GREATER THAN 31
   WHEN (date_part('month',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) = 12 AND date_part('day',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) > 31) THEN ((date_part('year',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) + 1) || '01' || '01')::DATE
   --WHEN DAY IS GREATER THAN 31
   WHEN (date_part('day',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) > 31) THEN (date_part('year',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) || (date_part('month',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) + 1) || '01')::DATE
   --WHEN MONTHS ARE APRIL, JUNE, SEPTEMBER, NOVEMBER AND DAY IS GRETAER THAN 30
   WHEN (date_part('month',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) IN (04,06,09,11) AND date_part('day',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) > 30) THEN (date_part('year',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) ||(date_part('month',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) + 1) || '01')::DATE
   --WHEN NOT A LEAP YEAR AND MONTH IS FEBUARY AND DAY IS GREATER THAN 28
   WHEN (CAST((date_part('year',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE)) AS INT) % 4 <> 0 AND date_part('month',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) = 02 AND date_part('day',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) > 28) THEN (date_part('year',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) ||(date_part('month',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) + 1) || '01')::DATE
   --WHEN LEAP YEAR, MONTH IS FEBUARY AND DAY IS GREATER THAN 29
   WHEN (CAST((date_part('year',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE)) AS INT) % 4 = 0 AND date_part('month',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) = 02 AND date_part('day',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) > 29) THEN (date_part('year',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) ||(date_part('month',ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE) + 1) || '01')::DATE
   ELSE
   ndt_dimcprf.db_exp_date::VARCHAR(8)::DATE
END;  --0

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt40010_imc_contracts ndt_imc_contracts ON atlas.imc_number = ndt_imc_contracts.imc_number
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.current_application_date = 
CASE
   --WHEN ENTRY DATE IS NULL THEN THERE SHOULD BE DEFAULT VALUE FOR DATE
   WHEN (ndt_imc_contracts.imc_expiration_date IS NULL OR ndt_imc_contracts.imc_expiration_date::VARCHAR = '') THEN '19000101'::DATE
   --WHEN MONTH IS DECEMBER AND DAY IS GREATER THAN 31
   WHEN (date_part('month',ndt_imc_contracts.imc_expiration_date::DATE) = 12 AND date_part('day',ndt_imc_contracts.imc_expiration_date::DATE) > 31) THEN ((date_part('year',ndt_imc_contracts.imc_expiration_date::DATE) + 1) || '01' || '01')::DATE
   --WHEN DAY IS GREATER THAN 31
   WHEN (date_part('day',ndt_imc_contracts.imc_expiration_date::DATE) > 31) THEN (date_part('year',ndt_imc_contracts.imc_expiration_date::DATE) || (date_part('month',ndt_imc_contracts.imc_expiration_date::DATE) + 1) || '01')::DATE
   --WHEN MONTHS ARE APRIL, JUNE, SEPTEMBER, NOVEMBER AND DAY IS GRETAER THAN 30
   WHEN (date_part('month',ndt_imc_contracts.imc_expiration_date::DATE) IN (04,06,09,11) AND date_part('day',ndt_imc_contracts.imc_expiration_date::DATE) > 30) THEN (date_part('year',ndt_imc_contracts.imc_expiration_date::DATE) ||(date_part('month',ndt_imc_contracts.imc_expiration_date::DATE) + 1) || '01')::DATE
   --WHEN NOT A LEAP YEAR AND MONTH IS FEBUARY AND DAY IS GREATER THAN 28
   WHEN (CAST((date_part('year',ndt_imc_contracts.imc_expiration_date::DATE)) AS INT) % 4 <> 0 AND date_part('month',ndt_imc_contracts.imc_expiration_date::DATE) = 02 AND date_part('day',ndt_imc_contracts.imc_expiration_date::DATE) > 28) THEN (date_part('year',ndt_imc_contracts.imc_expiration_date::DATE) ||(date_part('month',ndt_imc_contracts.imc_expiration_date::DATE) + 1) || '01')::DATE
   --WHEN LEAP YEAR, MONTH IS FEBUARY AND DAY IS GREATER THAN 29
   WHEN (CAST((date_part('year',ndt_imc_contracts.imc_expiration_date::DATE)) AS INT) % 4 = 0 AND date_part('month',ndt_imc_contracts.imc_expiration_date::DATE) = 02 AND date_part('day',ndt_imc_contracts.imc_expiration_date::DATE) > 29) THEN (date_part('year',ndt_imc_contracts.imc_expiration_date::DATE) ||(date_part('month',ndt_imc_contracts.imc_expiration_date::DATE) + 1) || '01')::DATE
   ELSE
   ndt_imc_contracts.imc_expiration_date::DATE
END;  --297

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  LEFT JOIN atomic_legacy.dwt40010_imc_contracts ndt_imc_contracts ON atlas.imc_number = ndt_imc_contracts.imc_number
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   ndt_imc_contracts.imc_number IS NULL 
AND   gam.expiration_date = '9998-12-31';  --119467

SELECT 119467 + 297;  --119764

--15. account_name

-- MUST NOT START AND END WITH SPACE (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.account_name <> ''
AND gam.account_name IS NOT NULL AND (substring(gam.account_name,1,1) = '' OR substring(gam.account_name,LENGTH(gam.account_name),1) = '');

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.account_name = ''
OR gam.account_name IS NULL;

--SPECIAL CHARACTERS ARE NOT ALLOWED (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.account_name ~ '^[#+,".<>/\|{}-]+$' = 'TRUE';
--'^[#$%&()*+,\-./:;<=>?@[\\\]^`{|}~]+$'

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.account_name = mdms.account_name;  --609435

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND gam.account_name = legacy.account_name;  --89792742

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.account_name = atlas.imc_name;  --1087477

--16. imc_type_code

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.imc_type_code = ''
OR gam.imc_type_code IS NULL;

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.imc_type_code = mdms.imc_type_code;  --609435

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND gam.imc_type_code = legacy.imc_type_code;  --77489262

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt43075_atlas_imc_type ndt_atlas_imc_type ON atlas.imc_type = ndt_atlas_imc_type.imc_type
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' 
AND gam.imc_type_code = ndt_atlas_imc_type.imc_type_code;  --1087477

--17. imc_type_desc

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.imc_type_desc = ''
OR gam.imc_type_desc IS NULL;

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.wwt01001_imc_type_mst ndt_imc_type_mst ON mdms.imc_type_code = ndt_imc_type_mst.imc_typ_cd
WHERE mdms.business_entity_code <> ''
AND   gam.imc_type_desc = ndt_imc_type_mst.imc_desc;  --609435

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic_legacy.dwt41047_ddsttyp ndt_ddsttyp ON legacy.imc_type_code = ndt_ddsttyp.dist_type AND legacy.business_entity_code = ndt_ddsttyp.intgrt_cntry_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND gam.imc_type_code = ndt_ddsttyp.dist_type_desc;  --77489262

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' 
AND gam.imc_type_code = atlas.imc_type;  --1087477

--18. business_nature_code

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.business_nature_code = ''
OR gam.business_nature_code IS NULL;

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.business_nature_code = mdms.business_nature_code;  --609435

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND gam.business_nature_code = legacy.business_nature_code;  --77489262

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' 
AND gam.business_nature_code = '*';  --1087477

--19. business_nature_name

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.business_nature_name = ''
OR gam.business_nature_name IS NULL;

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.wwt06004_bus_natr_mst ndt_bus_natr_mst
    ON ndt_bus_natr_mst.Cntry_Cd::SMALLINT = CASE WHEN trim (mdms.Business_Entity_Code) = '' THEN 0 ELSE mdms.Business_Entity_Code::SMALLINT END
   AND mdms.Business_Nature_Code = ndt_bus_natr_mst.Bus_Natr_Cd
WHERE mdms.business_entity_code <> ''
AND   gam.business_nature_name = ndt_bus_natr_mst.bus_natr_nm;  --1655154

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic_legacy.dwt41046_dbusnat ndt_dbusnat ON legacy.business_nature_code = ndt_dbusnat.bus_nat_cd AND legacy.business_entity_code = ndt_dbusnat.intgrt_cntry_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND gam.business_nature_name = ndt_dbusnat.bus_nat_desc;  --78730857

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	LEFT JOIN atomic_legacy.dwt41046_dbusnat ndt_dbusnat ON legacy.business_nature_code = ndt_dbusnat.bus_nat_cd AND legacy.business_entity_code = ndt_dbusnat.intgrt_cntry_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND   ndt_dbusnat.bus_nat_cd IS NULL
AND gam.business_nature_name = 'UNKNOWN';  --10921866

SELECT 78730857 + 10921866;  --89652723

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' 
AND gam.business_nature_name = 'UNKNOWN';  --592748

--20. business_status_code

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.business_status_code = ''
OR gam.business_status_code IS NULL;

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.business_status_code = mdms.account_business_status_code;  --1655162

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND gam.business_status_code = legacy.account_business_status_code;  --89652723

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' 
AND gam.business_status_code = 
CASE 
WHEN LOWER(atlas.status) = 'active' THEN '1'
ELSE 
'2'
END;  --592748

--21. business_status

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.business_status = ''
OR gam.business_status IS NULL;  --8352

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.mv00002_bus_stat_dim ndt_bus_stat_dim ON mdms.Account_Business_Status_Code::VARCHAR (10) = ndt_bus_stat_dim.imc_bus_stat_cd
WHERE mdms.business_entity_code <> ''
AND   gam.business_status = ndt_bus_stat_dim.globl_bus_stat_cd;  --1655199

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic.mv00002_bus_stat_dim ndt_bus_stat_dim ON legacy.Account_Business_Status_Code = ndt_bus_stat_dim.imc_bus_stat_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND gam.business_status = ndt_bus_stat_dim.globl_bus_stat_cd;  --89652723

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic.mv00002_bus_stat_dim ndt_bus_stat_dim ON atlas.status = ndt_bus_stat_dim.imc_bus_stat_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' 
AND gam.business_status = ndt_bus_stat_dim.globl_bus_stat_cd;  --592748

--22. status_reason_code

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.status_reason_code = ''
OR gam.status_reason_code IS NULL;  --8352

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.mv00002_bus_stat_dim ndt_bus_stat_dim ON mdms.Account_Business_Status_Code::VARCHAR (10) = ndt_bus_stat_dim.imc_bus_stat_cd
WHERE mdms.business_entity_code <> ''
AND   gam.status_reason_code = ndt_bus_stat_dim.imc_bus_stat_cd;  --1655199

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic.mv00002_bus_stat_dim ndt_bus_stat_dim ON legacy.Account_Business_Status_Code = ndt_bus_stat_dim.imc_bus_stat_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND gam.status_reason_code = ndt_bus_stat_dim.imc_bus_stat_cd;  --89652723

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic.mv00002_bus_stat_dim ndt_bus_stat_dim ON atlas.status = ndt_bus_stat_dim.imc_bus_stat_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' 
AND gam.status_reason_code = ndt_bus_stat_dim.imc_bus_stat_cd;  --592748

--23. status_reason_description

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.status_reason_description = ''
OR gam.status_reason_description IS NULL;  --8352

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.mv00002_bus_stat_dim ndt_bus_stat_dim ON mdms.Account_Business_Status_Code::VARCHAR (10) = ndt_bus_stat_dim.imc_bus_stat_cd
WHERE mdms.business_entity_code <> ''
AND   gam.status_reason_description = ndt_bus_stat_dim.imc_bus_stat_desc;  --1655199

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic.mv00002_bus_stat_dim ndt_bus_stat_dim ON legacy.Account_Business_Status_Code = ndt_bus_stat_dim.imc_bus_stat_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND gam.status_reason_description = ndt_bus_stat_dim.imc_bus_stat_desc;  --89652723

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic.mv00002_bus_stat_dim ndt_bus_stat_dim ON atlas.status = ndt_bus_stat_dim.imc_bus_stat_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' 
AND gam.status_reason_description = ndt_bus_stat_dim.imc_bus_stat_desc;  --592733

--24. account_segment_code

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.account_segment_code = ''
OR gam.account_segment_code IS NULL;  --25498

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.account_segment_code = mdms.account_segment_code;  --1655199

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND gam.account_segment_code = legacy.account_segment_code;  --89652723

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic.wwt01080_ibo_inf_mst ndt_ibo_inf_mst 
  ON ndt_ibo_inf_mst.aff_id = gam.affiliate_code AND ndt_ibo_inf_mst.ibo_no = gam.abo_number
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' 
AND gam.account_segment_code = ndt_ibo_inf_mst.class_cd;   --590657

--25. account_segment_name

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.account_segment_name = ''
OR gam.account_segment_name IS NULL;  --25498

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.wwt03081_seg_mst ndt_seg_mst
  ON ndt_seg_mst.Cntry_Cd::SMALLINT = 
    case
        when trim(mdms.Business_Entity_Code) = '' then 0
        else mdms.Business_Entity_Code::SMALLINT
    end
  AND mdms.Account_Segment_Code = ndt_seg_mst.Seg_Cd
WHERE mdms.business_entity_code <> ''
AND   gam.account_segment_name = ndt_seg_mst.seg_desc;  --1649485

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic.wwt03081_seg_mst seg
    ON legacy.Business_Entity_Code = seg.Cntry_Cd
    AND legacy.Account_Segment_Code = seg.Seg_Cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND gam.account_segment_name = seg.seg_nm;  --89625488

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic.wwt03081_seg_mst seg
  ON gam.business_entity_code = seg.Cntry_Cd
   AND gam.account_segment_code = seg.Seg_Cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   gam.account_segment_name = 
CASE
   WHEN seg.seg_desc = 'Silver Producer' THEN 'SILVER_PRODUCER'
   WHEN seg.seg_desc = 'Platinum' THEN 'PLATINUM_AND_ABOVE'
   WHEN seg.seg_desc = 'Silver Sponsor' THEN 'SILVER_SPONSOR'
   WHEN seg.seg_desc = 'Associate' THEN 'ASSOCIATE'
   WHEN seg.seg_desc = 'Non Group Leader' THEN 'ASSOCIATE_IMC'
END;  --589048

--26. legal_entity_flag

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.legal_entity_flag = mdms.legal_entity_flag;  --1655373

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND gam.legal_entity_flag = 
CASE
  WHEN TRIM(legacy.legal_entity_type_code) <> '' AND legacy.legal_entity_type_code IS NOT NULL AND legacy.legal_entity_type_code <> 'N'
    THEN 'Y'
  ELSE legacy.legal_entity_type_code
END;  --89652688

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   gam.legal_entity_flag = 
CASE
   WHEN atlas.legal_entity_type IS NOT NULL THEN 'Y'
   ELSE 'N'
END;  --591125

--27. legal_entity_type_code

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.legal_entity_type_code = mdms.legal_entity_type_code;  --1655373

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND gam.legal_entity_type_code = legacy.legal_entity_type_code;  --89652688

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   gam.legal_entity_type_code = SUBSTRING(atlas.legal_entity_type,1,1);  --591125

--28. legal_entity_type_desc

--MEST BE ALPHABETIC (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE TRIM(gam.legal_entity_type_desc) <> '' AND gam.legal_entity_type_desc ~ '^[A-Z]+$' = 'FALSE';

--MDMS 
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.wwt01002_lgl_entty_typ ndt_lgl_entty_typ ON mdms.Legal_Entity_Type_Code = ndt_lgl_entty_typ.Legal_Entty_Type_Cd
WHERE mdms.business_entity_code <> ''
AND   gam.legal_entity_type_desc = ndt_lgl_entty_typ.lgl_entty_desc;  --1655373

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.wwt01002_lgl_entty_typ ndt_lgl_entty_typ ON legacy.Legal_Entity_Type_Code = ndt_lgl_entty_typ.Legal_Entty_Type_Cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND gam.legal_entity_type_desc = ndt_lgl_entty_typ.lgl_entty_desc;  --89652688

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   gam.legal_entity_type_desc = atlas.legal_entity_type;

--29. line_of_affiliation_code

--MEST NOT BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE TRIM(gam.line_of_affiliation_code) = '' AND gam.line_of_affiliation_code IS NULL;

--MEST ONLY ALLOW NUMERIC VALUES (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE TRIM(gam.line_of_affiliation_code) <> '' AND gam.line_of_affiliation_code IS NOT NULL AND gam.line_of_affiliation_code ~ '^[0-9]+$' = 'FALSE';

--MDMS 
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.line_of_affiliation_code = mdms.line_of_affiliation_code;  --1655373

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND gam.line_of_affiliation_code = legacy.line_of_affiliation_code;  --89652688

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   gam.line_of_affiliation_code = atlas.loa;  --592724

--30. sponsor_global_account_wid

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.wwt01080_ibo_inf_mst ndt_ibo_inf_mst ON LPAD (mdms.affiliate_code,3,'0') = LPAD (ndt_ibo_inf_mst.aff_id,3,'0') AND mdms.abo_no = ndt_ibo_inf_mst.ibo_no
  JOIN surrogate.sg_global_account_master sg_gam ON sg_gam.affiliate_code = gam.affiliate_code AND sg_gam.abo_number = ndt_ibo_inf_mst.spon_ibo_no
WHERE gam.sponsor_global_account_wid = sg_gam.global_account_wid;  --1566147   1657540

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic.wwt01080_ibo_inf_mst ndt_ibo_inf_mst ON LPAD (legacy.affiliate_code,3,'0') = LPAD (ndt_ibo_inf_mst.aff_id,3,'0') AND legacy.abo_no = ndt_ibo_inf_mst.ibo_no
  JOIN surrogate.sg_global_account_master sg_gam ON sg_gam.affiliate_code = gam.affiliate_code AND sg_gam.abo_number = ndt_ibo_inf_mst.spon_ibo_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND   gam.sponsor_global_account_wid = sg_gam.global_account_wid;  --1566147   1657540

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic.wwt01080_ibo_inf_mst ndt_ibo_inf_mst ON atlas.imc_number = CONCAT( LPAD (ndt_ibo_inf_mst.aff_id,3,'0'), ndt_ibo_inf_mst.ibo_no)
  JOIN surrogate.sg_global_account_master sg_gam ON sg_gam.affiliate_code = gam.affiliate_code AND sg_gam.abo_number = ndt_ibo_inf_mst.spon_ibo_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   gam.sponsor_global_account_wid = sg_gam.global_account_wid;  --592724

--31. sponsor_global_account_id       *****************************TODO***************************

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.wwt01020_aff_mst ndt_aff_mst
    ON ndt_aff_mst.aff_id = LPAD( mdms.affiliate_code,3,'0')::SMALLINT
    AND mdms.ABO_No = ndt_aff_mst.amway_alias_ibo_no
WHERE gam.sponsor_global_account_id = ndt_aff_mst.amway_alias_ibo_no;  --1566147   1657540

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.wwt01020_aff_mst ndt_aff_mst
    ON ndt_aff_mst.aff_id = LPAD( mdms.affiliate_code,3,'0')::SMALLINT
    AND mdms.ABO_No = ndt_aff_mst.amway_alias_ibo_no
  JOIN atomic.wwt01080_ibo_inf_mst ndt_ibo_inf_mst ON LPAD (mdms.affiliate_code,3,'0') = LPAD (ndt_ibo_inf_mst.aff_id,3,'0') AND mdms.abo_no = ndt_ibo_inf_mst.ibo_no
  --JOIN  atomic.wwt01020_aff_mst ndt_aff_mst ON ndt_aff_mst.aff_id::SMALLINT = 10
WHERE gam.sponsor_global_account_id = 
   CASE
        WHEN ndt_aff_mst.amway_alias_ibo_no IS NULL THEN CONCAT( LPAD (mdms.affiliate_code,3,'0'),ndt_ibo_inf_mst.spon_ibo_no)
        ELSE lpad(ndt_aff_mst.aff_id, 3, '0') || ndt_aff_mst.amway_alias_ibo_no --'0109995'
   END;

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic.wwt01080_ibo_inf_mst ndt_ibo_inf_mst ON LPAD (legacy.affiliate_code,3,'0') = LPAD (ndt_ibo_inf_mst.aff_id,3,'0') AND legacy.abo_no = ndt_ibo_inf_mst.ibo_no
  JOIN surrogate.sg_global_account_master sg_gam ON sg_gam.affiliate_code = gam.affiliate_code AND sg_gam.abo_number = ndt_ibo_inf_mst.spon_ibo_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND   gam.sponsor_global_account_wid = sg_gam.global_account_wid;  --1566147   1657540

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic.wwt01080_ibo_inf_mst ndt_ibo_inf_mst ON atlas.imc_number = CONCAT( LPAD (ndt_ibo_inf_mst.aff_id,3,'0'), ndt_ibo_inf_mst.ibo_no)
  JOIN surrogate.sg_global_account_master sg_gam ON sg_gam.affiliate_code = gam.affiliate_code AND sg_gam.abo_number = ndt_ibo_inf_mst.spon_ibo_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   gam.sponsor_global_account_wid = sg_gam.global_account_wid;  --592724

--32. sponsor_abo_number

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.wwt01080_ibo_inf_mst ndt_ibo_inf_mst ON LPAD (mdms.affiliate_code,3,'0') = LPAD (ndt_ibo_inf_mst.aff_id,3,'0') AND mdms.abo_no = ndt_ibo_inf_mst.ibo_no
WHERE gam.sponsor_abo_number = ndt_ibo_inf_mst.spon_ibo_no;  --1680913

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN atomic.wwt01080_ibo_inf_mst ndt_ibo_inf_mst ON LPAD (mdms.affiliate_code,3,'0') = LPAD (ndt_ibo_inf_mst.aff_id,3,'0') AND mdms.abo_no = ndt_ibo_inf_mst.ibo_no
WHERE ndt_ibo_inf_mst.aff_id IS NULL
AND gam.sponsor_abo_number <> mdms.sponsor_abo_no;  --108000

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN atomic.wwt01080_ibo_inf_mst ndt_ibo_inf_mst ON LPAD (mdms.affiliate_code,3,'0') = LPAD (ndt_ibo_inf_mst.aff_id,3,'0') AND mdms.abo_no = ndt_ibo_inf_mst.ibo_no
WHERE ndt_ibo_inf_mst.aff_id IS NULL
AND gam.sponsor_abo_number <> mdms.sponsor_abo_no;  --5

SELECT 1680913 + 108000;  --1788913

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic.wwt01080_ibo_inf_mst ndt_ibo_inf_mst ON LPAD (legacy.affiliate_code,3,'0') = LPAD (ndt_ibo_inf_mst.aff_id,3,'0') AND legacy.abo_no = ndt_ibo_inf_mst.ibo_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''  --74340525
AND   gam.sponsor_abo_number = ndt_ibo_inf_mst.spon_ibo_no;  --74340525

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	LEFT JOIN atomic.wwt01080_ibo_inf_mst ndt_ibo_inf_mst ON LPAD (legacy.affiliate_code,3,'0') = LPAD (ndt_ibo_inf_mst.aff_id,3,'0') AND legacy.abo_no = ndt_ibo_inf_mst.ibo_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND   ndt_ibo_inf_mst.aff_id IS NULL
AND   gam.sponsor_abo_number = legacy.sponsor_abo_no;  --15323163

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	LEFT JOIN atomic.wwt01080_ibo_inf_mst ndt_ibo_inf_mst ON LPAD (legacy.affiliate_code,3,'0') = LPAD (ndt_ibo_inf_mst.aff_id,3,'0') AND legacy.abo_no = ndt_ibo_inf_mst.ibo_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND   ndt_ibo_inf_mst.aff_id IS NULL
AND   legacy.sponsor_abo_no IS NULL
AND   gam.sponsor_abo_number IS NULL;  --405

SELECT 74340525 + 15323163 + 405;  --89664093

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
	JOIN atomic.wwt01080_ibo_inf_mst ndt_ibo_inf_mst ON atlas.imc_number = CONCAT( LPAD (ndt_ibo_inf_mst.aff_id,3,'0'), ndt_ibo_inf_mst.ibo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   gam.sponsor_abo_number = ndt_ibo_inf_mst.spon_ibo_no;  --591831

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
	LEFT JOIN atomic.wwt01080_ibo_inf_mst ndt_ibo_inf_mst ON atlas.imc_number = CONCAT( LPAD (ndt_ibo_inf_mst.aff_id,3,'0'), ndt_ibo_inf_mst.ibo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   ndt_ibo_inf_mst.aff_id IS NULL
AND   gam.sponsor_abo_number = SUBSTRING(atlas.sponsor_no,4);  --1745

--33, 34, 35. international_sponsor_global_account_wid, international_sponsor_abo_number, international_sponsor_affiliate_code

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN surrogate.sg_global_account_master sg
    ON gam.international_sponsor_affiliate_code = sg.affiliate_code
   AND gam.international_sponsor_abo_number = sg.abo_number
	WHERE gam.international_sponsor_global_account_wid = sg.global_account_wid; -- 92106732
	
--36. source_name

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE gam.source_name = 'dwt41141_account_dtl';  --1788918

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND   gam.source_name = 'dwt41042_distb_dtl';  --1566147

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   gam.source_name = 'dwt40016_imc'; --1566147

--37. application_entry_date

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE mdms.business_entity_code <> ''
AND 
CASE
WHEN imd1.curr_appl_dt_key_no - imd1.appl_dt_key_no > 365 THEN gam.application_entry_date = imd1.curr_appl_dt_key_no::VARCHAR(10)::DATE
ELSE
gam.application_entry_date = imd1.appl_dt_key_no::VARCHAR(10)::DATE
END;  --470973

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE mdms.business_entity_code <> ''
AND 
CASE
WHEN imd1.curr_appl_dt_key_no - imd1.appl_dt_key_no > 365
  THEN gam.application_entry_date <> imd1.curr_appl_dt_key_no::VARCHAR(10)::DATE
  AND gam.wd_first_insert_timestamp <> mdms.updt_dt
ELSE
  gam.application_entry_date <> imd1.appl_dt_key_no::VARCHAR(10)::DATE
  AND gam.wd_first_insert_timestamp <> mdms.updt_dt
END;  --8961

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE mdms.business_entity_code <> ''
AND imd1.imc_aff_id IS NULL
AND gam.application_entry_date = mdms.entry_date::DATE;  --124549

SELECT 470973 + 8961 + 124549;  --604483

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (legacy.affiliate_code) = '' THEN 0 ELSE legacy.affiliate_code::SMALLINT END
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND 
CASE
WHEN imd1.curr_appl_dt_key_no - imd1.appl_dt_key_no > 365 THEN gam.application_entry_date = imd1.curr_appl_dt_key_no::VARCHAR(10)::DATE
ELSE
gam.application_entry_date = imd1.appl_dt_key_no::VARCHAR(10)::DATE
END;  --88701190

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (legacy.affiliate_code) = '' THEN 0 ELSE legacy.affiliate_code::SMALLINT END
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND 
CASE
WHEN imd1.curr_appl_dt_key_no - imd1.appl_dt_key_no > 365 
  THEN gam.application_entry_date <> imd1.curr_appl_dt_key_no::VARCHAR(10)::DATE
ELSE
  gam.application_entry_date <> imd1.appl_dt_key_no::VARCHAR(10)::DATE
END;  --259981

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (legacy.affiliate_code) = '' THEN 0 ELSE legacy.affiliate_code::SMALLINT END
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND imd1.imc_aff_id IS NULL
AND gam.application_entry_date = legacy.signed_contract_date::DATE;  --704800

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (legacy.affiliate_code) = '' THEN 0 ELSE legacy.affiliate_code::SMALLINT END
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND legacy.signed_contract_date IS NULL
AND gam.application_entry_date = '19000101'::DATE;  --126770

SELECT 88701190 + 259981 + 704800 + 126770;  --89792741

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND 
CASE
WHEN imd1.curr_appl_dt_key_no - imd1.appl_dt_key_no > 365 THEN gam.application_entry_date = imd1.curr_appl_dt_key_no::VARCHAR(10)::DATE
ELSE
gam.application_entry_date = imd1.appl_dt_key_no::VARCHAR(10)::DATE
END;  --1064855

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND 
CASE
WHEN imd1.curr_appl_dt_key_no - imd1.appl_dt_key_no > 365  
  THEN gam.application_entry_date <> imd1.curr_appl_dt_key_no::VARCHAR(10)::DATE
ELSE
  gam.application_entry_date <> imd1.appl_dt_key_no::VARCHAR(10)::DATE
END;  --3

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  LEFT JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND imd1.imc_aff_id IS NULL
AND atlas.application_date <> ''
AND gam.application_entry_date = atlas.application_date::VARCHAR(10)::DATE;  --22602

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  LEFT JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND imd1.imc_aff_id IS NULL
AND atlas.application_date = ''
AND gam.application_entry_date = '19000101'::DATE;  --1596

SELECT 1064855 + 3 + 22602 + 1596;  --1089056

--38. current_application_date

--MDMS
SELECT COUNT(*) 
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.current_application_date = mdms.entry_date::DATE;  --604481

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND gam.current_application_date = 
CASE
WHEN (legacy.signed_contract_date IS NULL OR TRIM(legacy.signed_contract_date) = '') THEN '19000101'::DATE
ELSE
legacy.signed_contract_date::DATE
END;  --89792742

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.current_application_date =  atlas.application_date::DATE;  --1045721

--39. sales_account_type_code

--MDMS
SELECT COUNT(*) 
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON LPAD( mdms.affiliate_code,3,'0')::SMALLINT = ndt_dist_type_legacy_lkp.aff_no
    AND mdms.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND mdms.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
WHERE mdms.business_entity_code <> ''
AND   gam.sales_account_type_code = ndt_dist_type_legacy_lkp.sales_account_type_code;  --1788141

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON LPAD( mdms.affiliate_code,3,'0')::SMALLINT = ndt_dist_type_legacy_lkp.aff_no
    AND mdms.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND mdms.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
WHERE mdms.business_entity_code <> ''
AND ndt_dist_type_legacy_lkp.aff_no IS NULL
AND   gam.sales_account_type_code IS NULL;  --943

SELECT 1788141 + 943;  --1789084

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON LPAD( legacy.affiliate_code,3,'0')::SMALLINT = ndt_dist_type_legacy_lkp.aff_no
    AND legacy.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND legacy.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND gam.sales_account_type_code = ndt_dist_type_legacy_lkp.sales_account_type_code;  --89664074

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt43075_atlas_imc_type ndt_atlas_imc_type ON atlas.imc_type = ndt_atlas_imc_type.imc_type
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
  ON '' = ndt_dist_type_legacy_lkp.local_business_nature_code
      AND ndt_atlas_imc_type.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
      AND NVL(atlas.intgrt_aff_cd,atlas.sales_plan_affiliate)::SMALLINT = ndt_dist_type_legacy_lkp.aff_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND gam.sales_account_type_code =  ndt_dist_type_legacy_lkp.sales_account_type_code;  --593582

--40. sales_account_type_desc

--MDMS
SELECT COUNT(*) 
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON LPAD( mdms.affiliate_code,3,'0')::SMALLINT = ndt_dist_type_legacy_lkp.aff_no
    AND mdms.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND mdms.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
  JOIN atomic.wwt01001_imc_type_mst imc_sales ON ndt_dist_type_legacy_lkp.sales_account_type_code = imc_sales.IMC_Typ_Cd
WHERE mdms.business_entity_code <> ''
AND   gam.sales_account_type_desc = imc_sales.imc_desc;  --1788255

SELECT COUNT(*) 
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON LPAD( mdms.affiliate_code,3,'0')::SMALLINT = ndt_dist_type_legacy_lkp.aff_no
    AND mdms.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND mdms.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
  LEFT JOIN atomic.wwt01001_imc_type_mst imc_sales ON ndt_dist_type_legacy_lkp.sales_account_type_code = imc_sales.IMC_Typ_Cd
WHERE mdms.business_entity_code <> ''
AND   imc_sales.IMC_Typ_Cd IS NULL
AND   ndt_dist_type_legacy_lkp.aff_no IS NULL
AND   gam.sales_account_type_desc IS NULL;  --943

SELECT 1788255 + 943;  --1789198

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON LPAD( legacy.affiliate_code,3,'0')::SMALLINT = ndt_dist_type_legacy_lkp.aff_no
    AND legacy.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND legacy.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
  JOIN atomic.wwt01001_imc_type_mst imc_sales ON ndt_dist_type_legacy_lkp.sales_account_type_code = imc_sales.IMC_Typ_Cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   gam.sales_account_type_desc = imc_sales.imc_desc;  --89667906

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt43075_atlas_imc_type ndt_atlas_imc_type ON atlas.imc_type = ndt_atlas_imc_type.imc_type
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
  ON '' = ndt_dist_type_legacy_lkp.local_business_nature_code
      AND ndt_atlas_imc_type.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
      AND NVL(atlas.intgrt_aff_cd,atlas.sales_plan_affiliate)::SMALLINT = ndt_dist_type_legacy_lkp.aff_no
  JOIN atomic.wwt01001_imc_type_mst imc_sales ON ndt_dist_type_legacy_lkp.sales_account_type_code = imc_sales.IMC_Typ_Cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   gam.sales_account_type_desc = imc_sales.imc_desc;  --593582

--41. local_account_type_code

--MDMS
SELECT COUNT(*) 
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.local_account_type_code = 'NA';  --1789198

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   gam.local_account_type_code = CONCAT( legacy.bns_cpbl, legacy.business_nature_code);  --89649537

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   (legacy.bns_cpbl IS NULL OR TRIM(legacy.bns_cpbl) = '')
AND   (legacy.business_nature_code IS NULL OR TRIM(legacy.business_nature_code) = '')
AND   gam.local_account_type_code = 'NA';  --18370

SELECT 89649537 + 18370;  --89667907

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   gam.local_account_type_code = 'NA';  --593582

--42. local_account_type_desc

--MDMS
SELECT COUNT(*) 
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.local_account_type_desc = 'NOT APPLICABLE';  --1789198

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic_legacy.dwt41067_local_imc_type lcl_imc_type
    ON lpad(lcl_imc_type.aff_id, 3, '0') = lpad(legacy.Affiliate_Code, 3, '0')
    AND lcl_imc_type.local_imc_type_cd = CONCAT( legacy.bns_cpbl, legacy.business_nature_code)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   gam.local_account_type_desc = lcl_imc_type.local_imc_type_desc;  --23037506

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	LEFT JOIN atomic_legacy.dwt41067_local_imc_type lcl_imc_type
    ON lpad(lcl_imc_type.aff_id, 3, '0') = lpad(legacy.Affiliate_Code, 3, '0')
    AND lcl_imc_type.local_imc_type_cd = CONCAT( legacy.bns_cpbl, legacy.business_nature_code)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   lcl_imc_type.aff_id IS NULL
AND   gam.local_account_type_desc = 'NOT APPLICABLE';  --66635928

SELECT 89649537 + 18370;  --89667907

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   gam.local_account_type_desc = 'NOT APPLICABLE';  --593646

--43. original_imc_type_code

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE mdms.business_entity_code <> ''
AND   (imd1.original_imc_type_cd IS NOT NULL AND TRIM(imd1.original_imc_type_cd) != '' AND TRIM(imd1.original_imc_type_cd) != '*')
AND   gam.original_imc_type_code = imd1.original_imc_type_cd;  --394956

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE mdms.business_entity_code <> ''
AND   (imd1.original_imc_type_cd IS NOT NULL AND TRIM(imd1.original_imc_type_cd) != '' AND TRIM(imd1.original_imc_type_cd) != '*')
AND   gam.original_imc_type_code <> imd1.original_imc_type_cd;  --6524

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE mdms.business_entity_code <> ''
AND   (imd1.original_imc_type_cd IS NULL OR TRIM(imd1.original_imc_type_cd) = '' OR TRIM(imd1.original_imc_type_cd) = '*')
AND   gam.original_imc_type_code = mdms.imc_type_code;  --78454

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE mdms.business_entity_code <> ''
AND   imd1.imc_aff_id IS NULL
AND   gam.original_imc_type_code = mdms.imc_type_code;  --124549

SELECT 394956 + 6524 + 124549 + 78454;  --526029

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (legacy.affiliate_code) = '' THEN 0 ELSE legacy.affiliate_code::SMALLINT END
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   (imd1.original_imc_type_cd IS NOT NULL AND TRIM(imd1.original_imc_type_cd) != '' AND TRIM(imd1.original_imc_type_cd) != '*')
AND   gam.original_imc_type_code = imd1.original_imc_type_cd; -- 73517233

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (legacy.affiliate_code) = '' THEN 0 ELSE legacy.affiliate_code::SMALLINT END
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   (imd1.original_imc_type_cd IS NOT NULL AND TRIM(imd1.original_imc_type_cd) != '' AND TRIM(imd1.original_imc_type_cd) != '*')
AND   gam.original_imc_type_code <> imd1.original_imc_type_cd; -- 0

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (legacy.affiliate_code) = '' THEN 0 ELSE legacy.affiliate_code::SMALLINT END
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   (imd1.original_imc_type_cd IS NULL OR TRIM(imd1.original_imc_type_cd) = '' OR TRIM(imd1.original_imc_type_cd) = '*')
AND   gam.original_imc_type_code = legacy.imc_type_code; -- 4553264

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (legacy.affiliate_code) = '' THEN 0 ELSE legacy.affiliate_code::SMALLINT END
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   (imd1.original_imc_type_cd IS NULL OR TRIM(imd1.original_imc_type_cd) = '' OR TRIM(imd1.original_imc_type_cd) = '*')
AND   gam.original_imc_type_code <> legacy.imc_type_code; -- 10890674

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (legacy.affiliate_code) = '' THEN 0 ELSE legacy.affiliate_code::SMALLINT END
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   imd1.imc_aff_id IS NULL
AND   gam.original_imc_type_code = legacy.imc_type_code; -- 551096

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (legacy.affiliate_code) = '' THEN 0 ELSE legacy.affiliate_code::SMALLINT END
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD (legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   imd1.imc_aff_id IS NULL
AND   gam.original_imc_type_code <> legacy.imc_type_code; -- 280474

SELECT 73517233 + 4553264 + 10890674 + 551096 + 280474;  --89792741

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   (imd1.original_imc_type_cd IS NOT NULL AND TRIM(imd1.original_imc_type_cd) != '' AND TRIM(imd1.original_imc_type_cd) != '*')
AND   gam.original_imc_type_code = imd1.original_imc_type_cd; -- 127222

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   (imd1.original_imc_type_cd IS NOT NULL AND TRIM(imd1.original_imc_type_cd) != '' AND TRIM(imd1.original_imc_type_cd) != '*')
AND   gam.original_imc_type_code <> imd1.original_imc_type_cd; -- 821334

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt43075_atlas_imc_type ndt_atlas_imc_type ON atlas.imc_type = ndt_atlas_imc_type.imc_type
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   (imd1.original_imc_type_cd IS NULL OR TRIM(imd1.original_imc_type_cd) = '' OR TRIM(imd1.original_imc_type_cd) = '*')
AND   gam.original_imc_type_code = ndt_atlas_imc_type.imc_type_code; -- 116302

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt43075_atlas_imc_type ndt_atlas_imc_type ON atlas.imc_type = ndt_atlas_imc_type.imc_type
  LEFT JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   imd1.imc_aff_id IS NULL
AND   gam.original_imc_type_code = ndt_atlas_imc_type.imc_type_code; -- 24198

SELECT 127222 + 821334 + 116302 + 24198;  --1089056

--44. original_imc_type_desc

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.wwt01001_imc_type_mst ndt_imc_type_mst ON mdms.imc_type_code = ndt_imc_type_mst.imc_typ_cd
WHERE mdms.business_entity_code <> '' AND gam.original_imc_type_desc = ndt_imc_type_mst.imc_desc;  --127067

SELECT count(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.wwt01001_imc_type_mst ndt_imc_type_mst ON mdms.imc_type_code = ndt_imc_type_mst.imc_typ_cd
WHERE mdms.business_entity_code <> '' AND gam.original_imc_type_desc <> ndt_imc_type_mst.imc_desc limit 100;  --477416

select 477416 + 127067;   --604483

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic_legacy.dwt41047_ddsttyp ndt_ddsttyp ON legacy.imc_type_code = ndt_ddsttyp.dist_type AND legacy.business_entity_code = ndt_ddsttyp.intgrt_cntry_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '' AND gam.original_imc_type_desc = ndt_ddsttyp.dist_type_desc; -- 71710621

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic_legacy.dwt41047_ddsttyp ndt_ddsttyp ON legacy.imc_type_code = ndt_ddsttyp.dist_type AND legacy.business_entity_code = ndt_ddsttyp.intgrt_cntry_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '' AND gam.original_imc_type_desc <> ndt_ddsttyp.dist_type_desc; -- 5427897

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	LEFT JOIN atomic_legacy.dwt41047_ddsttyp ndt_ddsttyp ON legacy.imc_type_code = ndt_ddsttyp.dist_type AND legacy.business_entity_code = ndt_ddsttyp.intgrt_cntry_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '' 
AND   ndt_ddsttyp.dist_type IS NULL
AND   gam.original_imc_type_desc = 'unknown';  --12654223

SELECT 71710621 + 5427897 + 12654223;  --89792741

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   gam.original_imc_type_desc = atlas.imc_type;  --24198

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   gam.original_imc_type_desc <> atlas.imc_type;  --1064858

SELECT 24198 + 1064858; --1089056

--45. original_business_nature_code

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
    AND gam.abo_number = imd1.imc_no
WHERE mdms.business_entity_code <> ''
AND (imd1.original_bus_natr_cd IS NOT NULL AND TRIM(imd1.original_bus_natr_cd) != '' AND TRIM(imd1.original_bus_natr_cd) != '*')
AND gam.original_business_nature_code = imd1.original_bus_natr_cd;  --416708

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
    AND gam.abo_number = imd1.imc_no
WHERE mdms.business_entity_code <> ''
AND (imd1.original_bus_natr_cd IS NOT NULL AND TRIM(imd1.original_bus_natr_cd) != '' AND TRIM(imd1.original_bus_natr_cd) != '*')
AND gam.original_business_nature_code <> imd1.original_bus_natr_cd;  --0

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
  ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
  AND gam.abo_number = imd1.imc_no
WHERE mdms.business_entity_code <> ''
AND (imd1.original_bus_natr_cd IS NULL OR TRIM(imd1.original_bus_natr_cd) = '' OR TRIM(imd1.original_bus_natr_cd) = '*')
AND gam.original_business_nature_code = mdms.business_nature_code;  --63226

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
    AND gam.abo_number = imd1.imc_no
WHERE mdms.business_entity_code <> ''
AND imd1.imc_aff_id IS NULL
AND gam.original_business_nature_code = mdms.business_nature_code;  --124549

SELECT 416708 + 63226 + 124549;  --604483

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND (imd1.original_bus_natr_cd IS NOT NULL AND TRIM(imd1.original_bus_natr_cd) != '' AND TRIM(imd1.original_bus_natr_cd) != '*')
AND gam.original_business_nature_code = imd1.original_bus_natr_cd; -- 76830128

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND (imd1.original_bus_natr_cd IS NULL OR TRIM(imd1.original_bus_natr_cd) = '' OR TRIM(imd1.original_bus_natr_cd) = '*')
AND gam.original_business_nature_code = legacy.business_nature_code -- 1740712

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND (imd1.original_bus_natr_cd IS NULL OR TRIM(imd1.original_bus_natr_cd) = '' OR TRIM(imd1.original_bus_natr_cd) = '*')
AND gam.original_business_nature_code <> legacy.business_nature_code -- 10390331

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	LEFT JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND imd1.imc_aff_id IS NULL
AND gam.original_business_nature_code <> legacy.business_nature_code; -- 731081

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	LEFT JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND imd1.imc_aff_id IS NULL
AND gam.original_business_nature_code <> legacy.business_nature_code; -- 100489

SELECT 76830128 + 1740712 + 10390331 + 731081 + 100489;  --89792741

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND (imd1.original_bus_natr_cd IS NULL OR imd1.original_bus_natr_cd = '' OR imd1.original_bus_natr_cd = '*' OR imd1.original_bus_natr_cd = 'UNKNOWN')
AND   gam.original_business_nature_code = '*'  --1064858

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  LEFT JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND imd1.imc_aff_id IS NULL
AND   gam.original_business_nature_code = '*'  --24198

SELECT 1064858 + 24198;  --1089056

--46. original_business_nature_name

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.wwt06004_bus_natr_mst ndt_bus_natr_mst
    ON ndt_bus_natr_mst.Cntry_Cd::SMALLINT = CASE WHEN trim (mdms.Business_Entity_Code) = '' THEN 0 ELSE mdms.Business_Entity_Code::SMALLINT END
   AND mdms.Business_Nature_Code = ndt_bus_natr_mst.Bus_Natr_Cd
WHERE mdms.business_entity_code <> ''
AND   gam.original_business_nature_name = ndt_bus_natr_mst.bus_natr_nm;  --124546

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.wwt06004_bus_natr_mst ndt_bus_natr_mst
    ON ndt_bus_natr_mst.Cntry_Cd::SMALLINT = CASE WHEN trim (mdms.Business_Entity_Code) = '' THEN 0 ELSE mdms.Business_Entity_Code::SMALLINT END
   AND mdms.Business_Nature_Code = ndt_bus_natr_mst.Bus_Natr_Cd
WHERE mdms.business_entity_code <> ''
AND   gam.original_business_nature_name <> ndt_bus_natr_mst.bus_natr_nm;  --479934

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN atomic.wwt06004_bus_natr_mst ndt_bus_natr_mst
    ON ndt_bus_natr_mst.Cntry_Cd::SMALLINT = CASE WHEN trim (mdms.Business_Entity_Code) = '' THEN 0 ELSE mdms.Business_Entity_Code::SMALLINT END
   AND mdms.Business_Nature_Code = ndt_bus_natr_mst.Bus_Natr_Cd
WHERE mdms.business_entity_code <> ''
AND   ndt_bus_natr_mst.cntry_cd IS NULL
AND   gam.original_business_nature_name = 'UNKNOWN';  --3

select 124546 + 479934 + 3;  --604483

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic_legacy.dwt41046_dbusnat ndt_dbusnat ON legacy.business_nature_code = ndt_dbusnat.bus_nat_cd AND legacy.business_entity_code = ndt_dbusnat.intgrt_cntry_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '' AND ndt_dbusnat.bus_nat_cd IS NOT NULL AND TRIM(ndt_dbusnat.bus_nat_desc) <> ''
 AND gam.original_business_nature_name = ndt_dbusnat.bus_nat_desc; -- 72387654

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	JOIN atomic_legacy.dwt41046_dbusnat ndt_dbusnat ON legacy.business_nature_code = ndt_dbusnat.bus_nat_cd AND legacy.business_entity_code = ndt_dbusnat.intgrt_cntry_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '' AND ndt_dbusnat.bus_nat_cd IS NOT NULL AND TRIM(ndt_dbusnat.bus_nat_desc) <> ''
AND gam.original_business_nature_name <> ndt_dbusnat.bus_nat_desc;  -- 6547509

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	LEFT JOIN atomic_legacy.dwt41046_dbusnat ndt_dbusnat ON legacy.business_nature_code = ndt_dbusnat.bus_nat_cd AND legacy.business_entity_code = ndt_dbusnat.intgrt_cntry_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   ndt_dbusnat.bus_nat_cd IS NULL
AND gam.original_business_nature_name = 'UNKNOWN';  -- 10490600

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
	LEFT JOIN atomic_legacy.dwt41046_dbusnat ndt_dbusnat ON legacy.business_nature_code = ndt_dbusnat.bus_nat_cd AND legacy.business_entity_code = ndt_dbusnat.intgrt_cntry_cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   ndt_dbusnat.bus_nat_cd IS NULL
AND gam.original_business_nature_name <> 'UNKNOWN';  --366978

SELECT 72387654 + 6547509 + 10490600 + 366978;  -- 89792741

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND (imd1.original_bus_natr_cd IS NULL OR imd1.original_bus_natr_cd = '' OR imd1.original_bus_natr_cd = '*' OR imd1.original_bus_natr_cd = 'UNKNOWN')
AND   gam.original_business_nature_name = 'UNKNOWN';  --1064858

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  LEFT JOIN public.imc_dim_qa imd1
    ON imd1.imc_aff_id = CASE WHEN TRIM (gam.Affiliate_Code) = '' THEN 0 ELSE gam.Affiliate_Code::SMALLINT END
   AND gam.abo_number = imd1.imc_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND imd1.imc_aff_id IS NULL
AND   gam.original_business_nature_name = 'UNKNOWN';  --24198

SELECT 1064858 + 24198;  --1089056

--47. original_application_date

--MDMS
SELECT COUNT(*) 
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.original_application_date = mdms.entry_date::DATE;  --1647351

SELECT COUNT(*) 
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.original_application_date <> mdms.entry_date::DATE;  --139212

SELECT 1647351 + 139212;

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR TRIM(mdms.business_entity_code) = '')
AND legacy.Business_Entity_Code <> '' AND gam.original_application_date = 
CASE
WHEN legacy.signed_contract_date IS NULL THEN '19000101'::DATE
ELSE
legacy.signed_contract_date::DATE
END;  --76373445

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND legacy.Business_Entity_Code <> ''
AND gam.original_application_date <> 
CASE
WHEN legacy.signed_contract_date IS NULL THEN '19000101'::DATE
ELSE
legacy.signed_contract_date::DATE
END; --12441858

SELECT 76373445 + 12441858;  --88815303

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND gam.original_application_date = atlas.application_date::DATE;

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.original_application_date <> atlas.application_date::DATE;

select 931296 + 174436; -- 1105732

--48, 49. original_sponsor_global_account_wid, original_sponsor_abo_number
SELECT COUNT(*)
FROM curated_integration.global_account_master gam  --92058121
  JOIN surrogate.sg_global_account_master sg
    ON gam.affiliate_code = sg.affiliate_code
   AND gam.original_sponsor_abo_number = sg.abo_number  --92057706
	WHERE gam.original_sponsor_global_account_wid = sg.global_account_wid;  --92057706
	
--50. original_sales_account_type_code

--MDMS   1792557
SELECT COUNT(*) 
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(mdms.Affiliate_Code) = '' then 0
  					else mdms.Affiliate_Code::SMALLINT
  				  end
    AND mdms.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND mdms.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
WHERE mdms.business_entity_code <> ''
AND   gam.original_sales_account_type_code = ndt_dist_type_legacy_lkp.sales_account_type_code;  --514043

SELECT COUNT(*) 
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(mdms.Affiliate_Code) = '' then 0
  					else mdms.Affiliate_Code::SMALLINT
  				  end
    AND mdms.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND mdms.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
WHERE mdms.business_entity_code <> ''
AND   gam.original_sales_account_type_code <> ndt_dist_type_legacy_lkp.sales_account_type_code;  --107971

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(mdms.Affiliate_Code) = '' then 0
  					else mdms.Affiliate_Code::SMALLINT
  				  end
    AND mdms.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND mdms.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
WHERE mdms.business_entity_code <> ''
AND   ndt_dist_type_legacy_lkp.aff_no IS NULL
AND   gam.original_sales_account_type_code = '*';  --128

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(mdms.Affiliate_Code) = '' then 0
  					else mdms.Affiliate_Code::SMALLINT
  				  end
    AND mdms.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND mdms.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
WHERE mdms.business_entity_code <> ''
AND ndt_dist_type_legacy_lkp.aff_no IS NULL
AND   gam.original_sales_account_type_code <> '*';  --114

SELECT 514043 + 107971 + 128 + 114;  --622256

--LEGACY    89677386
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(legacy.Affiliate_Code) = '' then 0
  					else legacy.Affiliate_Code::SMALLINT
  				  end
    AND legacy.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND legacy.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''  --89677385
AND gam.original_sales_account_type_code = ndt_dist_type_legacy_lkp.sales_account_type_code;  --83314664

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(legacy.Affiliate_Code) = '' then 0
  					else legacy.Affiliate_Code::SMALLINT
  				  end
    AND legacy.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND legacy.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   gam.original_sales_account_type_code <> ndt_dist_type_legacy_lkp.sales_account_type_code;  --7026720

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(legacy.Affiliate_Code) = '' then 0
  					else legacy.Affiliate_Code::SMALLINT
  				  end
    AND legacy.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND legacy.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   ndt_dist_type_legacy_lkp.aff_no IS NULL
AND   gam.original_sales_account_type_code = '*';  --0

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(legacy.Affiliate_Code) = '' then 0
  					else legacy.Affiliate_Code::SMALLINT
  				  end
    AND legacy.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND legacy.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   ndt_dist_type_legacy_lkp.aff_no IS NULL
AND   gam.original_sales_account_type_code <> '*';  --1

SELECT 83314664 + 7026720 + 1;  --90341385

--ATLAS  --593667
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt43075_atlas_imc_type ndt_atlas_imc_type ON atlas.imc_type = ndt_atlas_imc_type.imc_type
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
  ON '' = ndt_dist_type_legacy_lkp.local_business_nature_code
      AND ndt_atlas_imc_type.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
      AND NVL(atlas.intgrt_aff_cd,atlas.sales_plan_affiliate)::SMALLINT = ndt_dist_type_legacy_lkp.aff_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND gam.original_sales_account_type_code =  ndt_dist_type_legacy_lkp.sales_account_type_code;  --1079564

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt43075_atlas_imc_type ndt_atlas_imc_type ON atlas.imc_type = ndt_atlas_imc_type.imc_type
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
  ON '' = ndt_dist_type_legacy_lkp.local_business_nature_code
      AND ndt_atlas_imc_type.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
      AND NVL(atlas.intgrt_aff_cd,atlas.sales_plan_affiliate)::SMALLINT = ndt_dist_type_legacy_lkp.aff_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND gam.original_sales_account_type_code <>  ndt_dist_type_legacy_lkp.sales_account_type_code;  --10350

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt43075_atlas_imc_type ndt_atlas_imc_type ON atlas.imc_type = ndt_atlas_imc_type.imc_type
  LEFT JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
  ON '' = ndt_dist_type_legacy_lkp.local_business_nature_code
      AND ndt_atlas_imc_type.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
      AND NVL(atlas.intgrt_aff_cd,atlas.sales_plan_affiliate)::SMALLINT = ndt_dist_type_legacy_lkp.aff_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND   ndt_dist_type_legacy_lkp.aff_no IS NULL
AND gam.original_sales_account_type_code = '*';  --10350

SELECT 1079564 + 10350;  --1089914

--51. original_sales_account_type_desc

--MDMS   1792557
SELECT COUNT(*) 
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(mdms.Affiliate_Code) = '' then 0
  					else mdms.Affiliate_Code::SMALLINT
  				  end
    AND mdms.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND mdms.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
  JOIN atomic.wwt01001_imc_type_mst imc_sales ON ndt_dist_type_legacy_lkp.sales_account_type_code = imc_sales.IMC_Typ_Cd
WHERE mdms.business_entity_code <> ''  --621952
AND   gam.original_sales_account_type_desc = imc_sales.imc_desc;  --513981

SELECT COUNT(*) 
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(mdms.Affiliate_Code) = '' then 0
  					else mdms.Affiliate_Code::SMALLINT
  				  end
    AND mdms.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND mdms.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
  JOIN atomic.wwt01001_imc_type_mst imc_sales ON ndt_dist_type_legacy_lkp.sales_account_type_code = imc_sales.IMC_Typ_Cd
WHERE mdms.business_entity_code <> ''
AND   gam.original_sales_account_type_desc <> imc_sales.imc_desc;  --107971

SELECT COUNT(*) 
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(mdms.Affiliate_Code) = '' then 0
  					else mdms.Affiliate_Code::SMALLINT
  				  end
    AND mdms.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND mdms.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
  LEFT JOIN atomic.wwt01001_imc_type_mst imc_sales ON ndt_dist_type_legacy_lkp.sales_account_type_code = imc_sales.IMC_Typ_Cd
WHERE mdms.business_entity_code <> ''
AND   imc_sales.IMC_Typ_Cd IS NULL
AND   gam.original_sales_account_type_desc = 'UNKNOWN';  --128

SELECT COUNT(*) 
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(mdms.Affiliate_Code) = '' then 0
  					else mdms.Affiliate_Code::SMALLINT
  				  end
    AND mdms.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND mdms.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
  LEFT JOIN atomic.wwt01001_imc_type_mst imc_sales ON ndt_dist_type_legacy_lkp.sales_account_type_code = imc_sales.IMC_Typ_Cd
WHERE mdms.business_entity_code <> ''
AND   ndt_dist_type_legacy_lkp.aff_no IS NULL
AND   imc_sales.IMC_Typ_Cd IS NULL
AND   gam.original_sales_account_type_desc = 'UNKNOWN';  --128

SELECT COUNT(*) 
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(mdms.Affiliate_Code) = '' then 0
  					else mdms.Affiliate_Code::SMALLINT
  				  end
    AND mdms.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND mdms.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
  LEFT JOIN atomic.wwt01001_imc_type_mst imc_sales ON ndt_dist_type_legacy_lkp.sales_account_type_code = imc_sales.IMC_Typ_Cd
WHERE mdms.business_entity_code <> ''
AND   ndt_dist_type_legacy_lkp.aff_no IS NULL
AND   imc_sales.IMC_Typ_Cd IS NULL
AND   gam.original_sales_account_type_desc <> 'UNKNOWN';  --114

SELECT 514043 + 107971 + 128 + 114;  --622256

--LEGACY    89677386
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(legacy.Affiliate_Code) = '' then 0
  					else legacy.Affiliate_Code::SMALLINT
  				  end
    AND legacy.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND legacy.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
  JOIN atomic.wwt01001_imc_type_mst imc_sales ON ndt_dist_type_legacy_lkp.sales_account_type_code = imc_sales.IMC_Typ_Cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''  --89677385
AND gam.original_sales_account_type_desc = imc_sales.imc_desc;  --83314664

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(legacy.Affiliate_Code) = '' then 0
  					else legacy.Affiliate_Code::SMALLINT
  				  end
    AND legacy.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND legacy.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
  JOIN atomic.wwt01001_imc_type_mst imc_sales ON ndt_dist_type_legacy_lkp.sales_account_type_code = imc_sales.IMC_Typ_Cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''  --89677385
AND gam.original_sales_account_type_desc <> imc_sales.imc_desc;  --7026720

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(legacy.Affiliate_Code) = '' then 0
  					else legacy.Affiliate_Code::SMALLINT
  				  end
    AND legacy.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND legacy.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
  LEFT JOIN atomic.wwt01001_imc_type_mst imc_sales ON ndt_dist_type_legacy_lkp.sales_account_type_code = imc_sales.IMC_Typ_Cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   imc_sales.IMC_Typ_Cd IS NULL
AND gam.original_sales_account_type_desc = 'UNKNOWN';  --0

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(legacy.Affiliate_Code) = '' then 0
  					else legacy.Affiliate_Code::SMALLINT
  				  end
    AND legacy.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND legacy.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
  LEFT JOIN atomic.wwt01001_imc_type_mst imc_sales ON ndt_dist_type_legacy_lkp.sales_account_type_code = imc_sales.IMC_Typ_Cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   imc_sales.IMC_Typ_Cd IS NULL
AND   ndt_dist_type_legacy_lkp.aff_no IS NULL
AND gam.original_sales_account_type_desc = 'UNKNOWN';  --0

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
    ON ndt_dist_type_legacy_lkp.aff_no = case
  					when trim(legacy.Affiliate_Code) = '' then 0
  					else legacy.Affiliate_Code::SMALLINT
  				  end
    AND legacy.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
    AND legacy.business_nature_code = ndt_dist_type_legacy_lkp.local_business_nature_code
  LEFT JOIN atomic.wwt01001_imc_type_mst imc_sales ON ndt_dist_type_legacy_lkp.sales_account_type_code = imc_sales.IMC_Typ_Cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND   imc_sales.IMC_Typ_Cd IS NULL
AND   ndt_dist_type_legacy_lkp.aff_no IS NULL
AND gam.original_sales_account_type_desc <> 'UNKNOWN';  --1

SELECT 83314664 + 7026720 + 1;  --90341385

--ATLAS  --593667
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt43075_atlas_imc_type ndt_atlas_imc_type ON atlas.imc_type = ndt_atlas_imc_type.imc_type
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
  ON '' = ndt_dist_type_legacy_lkp.local_business_nature_code
      AND ndt_atlas_imc_type.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
      AND NVL(atlas.intgrt_aff_cd,atlas.sales_plan_affiliate)::SMALLINT = ndt_dist_type_legacy_lkp.aff_no
  JOIN atomic.wwt01001_imc_type_mst imc_sales ON ndt_dist_type_legacy_lkp.sales_account_type_code = imc_sales.IMC_Typ_Cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND gam.original_sales_account_type_desc =  imc_sales.imc_desc;  --1079564

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
  JOIN atomic_legacy.dwt43075_atlas_imc_type ndt_atlas_imc_type ON atlas.imc_type = ndt_atlas_imc_type.imc_type
  JOIN atomic_legacy.dwt41150_dist_type_legacy_lkp ndt_dist_type_legacy_lkp
  ON '' = ndt_dist_type_legacy_lkp.local_business_nature_code
      AND ndt_atlas_imc_type.imc_type_code = ndt_dist_type_legacy_lkp.local_imc_type_code
      AND NVL(atlas.intgrt_aff_cd,atlas.sales_plan_affiliate)::SMALLINT = ndt_dist_type_legacy_lkp.aff_no
  JOIN atomic.wwt01001_imc_type_mst imc_sales ON ndt_dist_type_legacy_lkp.sales_account_type_code = imc_sales.IMC_Typ_Cd
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND gam.original_sales_account_type_desc <>  imc_sales.imc_desc;  --10350

SELECT 1079564 + 10350;  --1089914

--52. is_test_sales_account

-----****************************************TODO*****************************************

--53, 54, 55. annual_sponsor_global_account_wid
SELECT COUNT(*)
FROM curated_integration.global_account_master gam  --92058121
  JOIN surrogate.sg_global_account_master sg
    ON gam.affiliate_code = sg.affiliate_code
   AND gam.annual_sponsor_abo_number = sg.abo_number  --92057706
	WHERE gam.annual_sponsor_global_account_wid = sg.global_account_wid;  --47660321

--56. last_renewal_date

--MDMS    625322
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.qa_dwt40000_acct_hist_mdms ndt_acct_hist_mdms
    ON LPAD(mdms.affiliate_code,3,'0') = LPAD( ndt_acct_hist_mdms.aff_no,3,'0')
    AND mdms.abo_no = ndt_acct_hist_mdms.ibo_no
WHERE mdms.business_entity_code <> ''
AND gam.last_renewal_date = ndt_acct_hist_mdms.proc_dt::DATE;  -- 83760

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN public.qa_dwt40000_acct_hist_mdms ndt_acct_hist_mdms
    ON LPAD(mdms.affiliate_code,3,'0') = LPAD( ndt_acct_hist_mdms.aff_no,3,'0')
    AND mdms.abo_no = ndt_acct_hist_mdms.ibo_no
WHERE mdms.business_entity_code <> ''
AND ndt_acct_hist_mdms.aff_no IS NULL
AND gam.last_renewal_date = '19000101'::DATE;  -- 541562

SELECT 83760 + 541562; --625322

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	JOIN public.dwt41036_ddatbat_renewal_qa bat ON bat.intgrt_ctl_aff = LPAD(legacy.affiliate_code,'3','0') AND bat.distb_nbr = legacy.abo_no
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR TRIM(mdms.business_entity_code) = '')
AND legacy.Business_Entity_Code <> ''  --29707708
AND gam.last_renewal_date = bat.db_dt::DATE;  --29707708

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN public.dwt41036_ddatbat_renewal_qa bat ON bat.intgrt_ctl_aff = LPAD(legacy.affiliate_code,'3','0') AND bat.distb_nbr = legacy.abo_no
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR TRIM(mdms.business_entity_code) = '')
AND legacy.Business_Entity_Code <> ''
AND bat.intgrt_ctl_aff IS NULL
AND gam.last_renewal_date = '19000101'::DATE; --60630828

SELECT 29707708 + 60630828;  --90338536

--ATLAS    1089909
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  JOIN public.dwt41064_imc_service_contracts_renewal_qa cntrct ON cntrct.imc_no = atlas.imc_number
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> ''
AND gam.last_renewal_date = cntrct.ord_dt;  --113718

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON gam.global_account_id = atlas.imc_number
  JOIN public.temp_dwt12011_qa temp ON atlas.home_country = temp.iso_cntry_cd
  LEFT JOIN public.dwt41064_imc_service_contracts_renewal_qa cntrct ON cntrct.imc_no = atlas.imc_number
  LEFT JOIN atomic_legacy.dwt41042_distb_dtl legacy ON atlas.imc_number = CONCAT(LPAD( legacy.affiliate_code,'3','0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT(LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(temp.amway_cntry_cd) <> '' AND cntrct.imc_no IS NULL AND gam.last_renewal_date = '19000101'; -- 976191

SELECT 113718 + 976191;   --1089909

--57. IS_AUTO_RENEWAL_SUBSCRIBED

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.dwt41149_account_party_subsc ndt
    ON mdms.abo_no = ndt.abo_no
   AND LPAD(mdms.affiliate_code,'3','0') = LPAD(ndt.aff,'3','0')
   AND ndt.publication_id = '50' AND ndt.subscription_level = 'Account'
WHERE mdms.business_entity_code <> '' AND gam.is_auto_renewal_subscribed IS TRUE;  -- 263501

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN atomic.dwt41149_account_party_subsc ndt
    ON mdms.abo_no = ndt.abo_no
   AND LPAD(mdms.affiliate_code,'3','0') = LPAD(ndt.aff,'3','0')
   AND ndt.publication_id = '50' AND ndt.subscription_level = 'Account'
WHERE ndt.abo_no IS NULL AND mdms.business_entity_code <> '' AND gam.is_auto_renewal_subscribed IS FALSE;  --8596068

SELECT 263501 + 8596068;  --8859569

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR mdms.business_entity_code = '')
AND   legacy.Business_Entity_Code <> '' AND legacy.auto_renew = 'Y' AND gam.is_auto_renewal_subscribed IS TRUE; -- 1900819

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR mdms.business_entity_code = '')
AND   legacy.Business_Entity_Code <> '' AND legacy.auto_renew <> 'Y' AND gam.is_auto_renewal_subscribed IS FALSE; -- 80217926

SELECT 1900819 + 80217926; -- 82118745

--ATLAS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.is_auto_renewal_subscribed IS TRUE; -- 0

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = gam.global_account_id
  JOIN PUBLIC.temp_dwt12011_qa tmp ON atlas.home_country = tmp.iso_cntry_cd
  LEFT JOIN (SELECT distb.affiliate_code,
                    distb.business_entity_code,
                    distb.abo_no
             FROM atomic_legacy.dwt41042_distb_dtl distb
               JOIN atomic.wwt01020_aff_mst am_valid_aff ON am_valid_aff.aff_id = CASE WHEN TRIM (distb.affiliate_code) = '' THEN 0 ELSE distb.affiliate_code::SMALLINT END) legacy ON atlas.imc_number = CONCAT (LPAD (legacy.affiliate_code,3,'0'),legacy.abo_no)
  LEFT JOIN atomic.dwt41141_account_dtl mdms ON atlas.imc_number = CONCAT (LPAD (mdms.affiliate_code,3,'0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   (legacy.affiliate_code IS NULL OR TRIM(legacy.business_entity_code) = '')
AND   TRIM(atlas.imc_type) <> 'INTERCOMPANY'
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.is_auto_renewal_subscribed IS FALSE;  --1109081




