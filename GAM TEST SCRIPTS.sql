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
SELECT COUNT(*) FROM curated_integration.global_account_master; -- 91703017
--SG_GAM COUNT
SELECT COUNT(*) FROM surrogate.sg_global_account_master; -- 92092601


---- ROWS that must came into gam

-- MDMS
SELECT COUNT(*)
FROM atomic.dwt41141_account_dtl WHERE business_entity_code <> ''; -- 1783222

-- LEGACY
SELECT COUNT(*)
FROM atomic_legacy.dwt41042_distb_dtl legacy
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT ( LPAD( legacy.affiliate_code,'3','0'), legacy.abo_no) = CONCAT ( LPAD( mdms.affiliate_code,'3','0'), mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR TRIM(mdms.business_entity_code) = '')
AND TRIM(legacy.business_entity_code) <> '';  -- 88814043

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
AND   TRIM(tmp.amway_cntry_cd) <> ''; -- 1105732

--TOTAL
SELECT 1783222 + 88814043 + 1105732; -- 91702997


---- In actual rows came into gam

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> '';  --1783355

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT ( LPAD( legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (mdms.affiliate_code IS NULL OR mdms.business_entity_code = '')
AND   TRIM(legacy.Business_Entity_Code) <> '';  --88814043

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
AND   TRIM(tmp.amway_cntry_cd) <> ''; -- 1105732

--TOTAL
SELECT 1783355 + 88814043 + 1105732; -- 91703130



----------------------------------------------------------2. CHECK DUPLICATES FOR DRIVER TABLES---------------------------------
--MDMS
SELECT LPAD(mdms.affiliate_code,'3','0'),
       mdms.abo_no,
       COUNT(*)
FROM atomic.dwt41141_account_dtl mdms
WHERE mdms.business_entity_code <> ''
GROUP BY 1,2
HAVING COUNT(*) > 1 LIMIT 10;  -- DUPLICATES FOUND

--LEGACY
SELECT LPAD(legacy.affiliate_code,'3','0'),
       legacy.abo_no,
       COUNT(*)
FROM atomic_legacy.dwt41042_distb_dtl legacy
WHERE legacy.Business_Entity_Code <> ''
GROUP BY 1,2
HAVING COUNT(*) > 1 LIMIT 10;  --0 

--ATLAS
SELECT atlas.imc_number,
       COUNT(*)
FROM atomic_legacy.dwt40016_imc atlas
JOIN public.temp_dwt12011_qa temp ON atlas.home_country = temp.iso_cntry_cd
WHERE atlas.imc_type <> 'INTERCOMPANY'
AND   temp.amway_cntry_cd <> ''
GROUP BY atlas.imc_number
HAVING COUNT(*) > 1 LIMIT 10;  --0

--GAM PK
SELECT global_account_wid,
       COUNT(*)
FROM curated_integration.global_account_master
GROUP BY 1
HAVING COUNT(*) > 1 LIMIT 10; -- FOUNT DUPLICATES

--GAM NK
SELECT global_account_id,
       COUNT(*)
FROM curated_integration.global_account_master
GROUP BY 1
HAVING COUNT(*) > 1 LIMIT 10; -- FOUND DUPLICATES

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


---------------------------------------------------------------------(3) SG DIM TESTING -------------------------------------------------------
--MDMS
SELECT COUNT(*)
FROM atomic.dwt41141_account_dtl mdms
  JOIN surrogate.sg_global_account_master sg_gam
    ON mdms.abo_no = sg_gam.abo_number
   AND LPAD (mdms.affiliate_code,'3','0') = sg_gam.affiliate_code
WHERE mdms.business_entity_code <> '';  -- 1783222

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
AND   legacy.Business_Entity_Code <> '';  -- 88814043

--ATLAS
SELECT COUNT(*)
FROM surrogate.sg_global_account_master sg_gam
  JOIN atomic_legacy.dwt40016_imc atlas ON atlas.imc_number = CONCAT(sg_gam.abo_number, sg_gam.affiliate_code)
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
AND   TRIM(tmp.amway_cntry_cd) <> ''; -- 2770
 
select 1783222 + 88814043 + 2770;  --90600035

---------------------------------------------------4. FIELD BY FIELD TESTING----------------------------------------
-- 1. global_account_wid
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN surrogate.sg_global_account_master sg_gam ON gam.affiliate_code = sg_gam.affiliate_code AND gam.abo_number = sg_gam.abo_number
  WHERE sg_gam.global_account_wid = gam.global_account_wid; -- 91703017
  
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN surrogate.sg_global_account_master sg_gam ON gam.global_account_id = CONCAT(sg_gam.affiliate_code,sg_gam.abo_number)
  WHERE sg_gam.global_account_wid = gam.global_account_wid; -- 91703006
  
-- 2. global_account_id

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

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> '' AND gam.account_id = mdms.account_id;  -- 1783355

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '' AND gam.account_id = legacy.abo_no; -- 89742352

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
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.account_id = SUBSTRING(atlas.imc_number,4)::BIGINT; -- 1087477

-- 4. abo_number

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> '' AND gam.abo_number = mdms.abo_no;  -- 1783355

--LEGACY
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '' AND gam.abo_number = legacy.abo_no; -- 88814043

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
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.abo_number = SUBSTRING(atlas.imc_number,4)::BIGINT; -- 1105732

-- 5. affiliate_code

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
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.affiliate_code = NVL(atlas.intgrt_aff_cd, atlas.sales_plan_affiliate); -- 1105732

-- 6. affiliate_name

--MDMS
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> '' AND gam.affiliate_name = mdms.  -- 1783355

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
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.affiliate_code = NVL(atlas.intgrt_aff_cd, atlas.sales_plan_affiliate); -- 1105732










































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















