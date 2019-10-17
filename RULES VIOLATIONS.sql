---------------------------------------------global_account_id

--MUST BE A NUMBER
SELECT gam.global_account_id
FROM curated_integration.global_account_master gam WHERE gam.global_account_id ~ '^[0-9]+$' = 'FALSE';  --91486521

---------------------------------------------account_id (SAME WITH ABO_NUMBER)

--MUST BE UNIQUE WITHIN A SYSTEM
SELECT COUNT(*), gam.account_id
FROM curated_integration.global_account_master gam
GROUP BY 2 HAVING(COUNT(*)) > 1 LIMIT 20;

--MDMS
SELECT COUNT(*), gam.account_id
FROM curated_integration.global_account_master gam
  JOIN atomic.dwt41141_account_dtl mdms ON gam.global_account_id = CONCAT (LPAD( mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE mdms.business_entity_code <> '' AND gam.account_id = mdms.account_id GROUP BY 2 HAVING (COUNT(*)) > 1 LIMIT 10;

--LEGACY
SELECT COUNT(*), gam.account_id
FROM curated_integration.global_account_master gam
  JOIN atomic_legacy.dwt41042_distb_dtl legacy ON gam.global_account_id = CONCAT( LPAD(legacy.affiliate_code,'3','0'), legacy.abo_no)
  JOIN atomic.wwt01020_aff_mst am_valid_aff
		ON am_valid_aff.aff_id = CASE WHEN TRIM(legacy.affiliate_code) = '' THEN 0	ELSE legacy.affiliate_code::SMALLINT END
	LEFT JOIN atomic.dwt41141_account_dtl mdms ON CONCAT (LPAD(legacy.affiliate_code,'3','0'),legacy.abo_no) = CONCAT (LPAD(mdms.affiliate_code,'3','0'),mdms.abo_no)
WHERE (CONCAT(mdms.affiliate_code,mdms.abo_no) IS NULL OR TRIM(mdms.business_entity_code) = '')
AND   legacy.Business_Entity_Code <> '' AND gam.account_id = legacy.abo_no GROUP BY 2 HAVING (COUNT(*)) > 1 LIMIT 10;

--ATLAS
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
AND   TRIM(tmp.amway_cntry_cd) <> '' AND gam.account_id = SUBSTRING(atlas.imc_number,4)::BIGINT GROUP BY 2 HAVING (COUNT(*)) > 1 LIMIT 10;

---------------------------------------------iso_currency_code

--(Must be all letters (A-Z))
SELECT gam.iso_currency_code
FROM curated_integration.global_account_master gam
WHERE gam.iso_currency_code <> '' AND gam.iso_currency_code ~ '^[A-Z]+$' = 'FALSE' LIMIT 10;

---------------------------------------------account_name

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
SELECT gam.account_name
FROM curated_integration.global_account_master gam
WHERE gam.account_name ~ '^[#+,".<>/\|{}-]+$' = 'TRUE' limit 10;
--'^[#$%&()*+,\-./:;<=>?@[\\\]^`{|}~]+$'

---------------------------------------------business_status_code

--MUST NOT BE BLANK (QR)
SELECT COUNT(*)
FROM curated_integration.global_account_master gam
WHERE gam.business_status_code = ''
OR gam.business_status_code IS NULL;

