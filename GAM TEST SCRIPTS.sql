-------------------------------------------CREATING NON DRIVER TABLE------------------------------------------
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

SELECT COUNT(*) FROM public.temp_dwt12011_qa;  --65

--------------------------------------------1. CHECK COUNTS---------------------------------------------------------------------

--GAM COUNT
SELECT COUNT(*) FROM curated_integration.global_account_master; -- 91977452
--SG_GAM COUNT
SELECT COUNT(*) FROM surrogate.sg_global_account_master; -- 92433794


---- ROWS that must came into gam

-- MDMS
SELECT COUNT(*)
FROM atomic.dwt41141_account_dtl WHERE business_entity_code <> ''; -- 6231588

-- LEGACY
SELECT COUNT(*)
FROM atomic_legacy.dwt41042_distb_dtl legacy
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT ( LPAD( legacy.affiliate_code,'3','0'), legacy.abo_no) = CONCAT ( LPAD( mdms.affiliate_code,'3','0'), mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND TRIM(legacy.business_entity_code) <> '';  -- 84637090

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
AND   TRIM(tmp.amway_cntry_cd) <> ''; -- 1108582

--TOTAL
SELECT 6231588 + 84637090 + 1108582; -- 91977260


---- In actual rows came into gam

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> '';  --6362780

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT ( LPAD( legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR mdms.business_entity_code = '')
AND   TRIM(legacy.Business_Entity_Code) <> '';  --84637090

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
AND   TRIM(tmp.amway_cntry_cd) <> ''; -- 1108582

--TOTAL
SELECT 6231780 + 84637090 + 1108582; -- 91977159


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
WHERE mdms.business_entity_code <> '';  -- 4944827

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
AND   legacy.Business_Entity_Code <> '';  -- 85878647

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
        AND TRIM(atlas.imc_type) <> 'INTERCOMPANY' AND TRIM(tmp.amway_cntry_cd) <> '';  --1108582
 
SELECT 4944827 + 85878647 + 1108582;  --91931919

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

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.signed_contract_date = mdms.entry_date::DATE;  --604481

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.dwt41036_ddatbat_qa ndt_ddatbat_qa ON ndt_ddatbat_qa.intgrt_ctl_aff = LPAD(legacy.affiliate_code,'3','0') AND ndt_ddatbat_qa.distb_nbr = legacy.abo_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND gam.signed_contract_date = ndt_ddatbat_qa.db_dt::DATE;  --269935

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN public.dwt41036_ddatbat_qa ndt_ddatbat_qa ON ndt_ddatbat_qa.intgrt_ctl_aff = LPAD(legacy.affiliate_code,'3','0') AND ndt_ddatbat_qa.distb_nbr = legacy.abo_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND ndt_ddatbat_qa.intgrt_ctl_aff IS NULL AND gam.signed_contract_date = '19000101'::DATE; -- 89522807

SELECT 269935 + 89522807; -- 89792742

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
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.signed_contract_date = atlas.signed_form_received_date::DATE;  --1087477


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
END;  --604483

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
AND   gam.business_nature_name = ndt_bus_natr_mst.bus_natr_nm;  --609435

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
AND gam.business_nature_name = ndt_dbusnat.bus_nat_desc;  --77489262

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
AND gam.business_nature_name = 'UNKNOWN';  --1087477

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
AND   gam.business_status_code = mdms.account_business_status_code;  --609435

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.business_entity_code <> ''
AND gam.business_status_code = legacy.account_business_status_code;  --77489262

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
END;  --1087477





--15. application_entry_date  --------------------------------------------------------------TODO

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.application_entry_date = mdms.entry_date::DATE;  --604481

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN public.dwt41036_ddatbat_qa ndt_ddatbat_qa ON ndt_ddatbat_qa.intgrt_ctl_aff = LPAD(legacy.affiliate_code,'3','0') AND ndt_ddatbat_qa.distb_nbr = legacy.abo_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND gam.application_entry_date = ndt_ddatbat_qa.db_dt::DATE;  --269935

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN public.dwt41036_ddatbat_qa ndt_ddatbat_qa ON ndt_ddatbat_qa.intgrt_ctl_aff = LPAD(legacy.affiliate_code,'3','0') AND ndt_ddatbat_qa.distb_nbr = legacy.abo_no
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND ndt_ddatbat_qa.intgrt_ctl_aff IS NULL AND gam.signed_contract_date = '19000101'::DATE; -- 89522807

SELECT 269935 + 89522807; -- 89792742

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
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.signed_contract_date = atlas.signed_form_received_date::DATE;  --1087477

--16. original_application_date  -----------------------------------------------------------------TODO

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

SELECT 1647351 + 139212; --1786563

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

SELECT 931296 + 174436; -- 1105732


--17. current_application_date

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
WHEN legacy.signed_contract_date IS NULL THEN '19000101'::DATE
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
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.current_application_date =  atlas.application_date::DATE;  --





--19. imc_type_code

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD (mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> ''
AND   gam.imc_type_code = mdms.imc_type_code;  --604481

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND gam.imc_type_code = legacy.imc_type_code;  --77138519

SELECT gam.imc_type_code, legacy.imc_type_code, gam.source_name
--COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> ''
AND gam.imc_type_code <> legacy.imc_type_code limit 10;  --12654223

select 77138519+12654223;  --89792742

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
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.imc_type_code = ndt_atlas_imc_type.imc_type_code;  --1087477























-- 6. IS_AUTO_RENEWAL_SUBSCRIBED
--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  JOIN atomic.dwt41149_account_party_subsc ndt
    ON mdms.abo_no = ndt.abo_no
   AND LPAD(mdms.affiliate_code,'3','0') = LPAD(ndt.aff,'3','0')
   AND ndt.publication_id = '50'
WHERE mdms.business_entity_code <> '' AND gam.is_auto_renewal_subscribed IS TRUE;  -- 137

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
  LEFT JOIN atomic.dwt41149_account_party_subsc ndt
    ON mdms.abo_no = ndt.abo_no
   AND LPAD(mdms.affiliate_code,'3','0') = LPAD(ndt.aff,'3','0')
   AND ndt.publication_id = '50'
WHERE ndt.abo_no IS NULL AND mdms.business_entity_code <> '' AND gam.is_auto_renewal_subscribed IS FALSE;  -- 1783218

SELECT 137 + 1783218;  --1783355

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR mdms.business_entity_code = '')
AND   legacy.Business_Entity_Code <> '' AND legacy.auto_renew = 'Y' AND gam.is_auto_renewal_subscribed IS TRUE; -- 2069011

SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR mdms.business_entity_code = '')
AND   legacy.Business_Entity_Code <> '' AND legacy.auto_renew <> 'Y' AND gam.is_auto_renewal_subscribed IS FALSE; -- 86745032

SELECT 2069011 + 86745032; -- 88814043

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
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.is_auto_renewal_subscribed IS FALSE;  --1105732

--TOTAL COUNT
SELECT 1783355 + 88814043 + 1105732;  --91703130















