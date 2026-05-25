-- ================================================================
-- JOB MARKET ANALYSIS — DATA ANALYST ROLES
-- ================================================================

USE ANALYSTS;

-- ================================================================
-- SECTION 1: DATA AUDIT & QUALITY CHECK
-- ================================================================

-- 1a. Total rows & basic shape
SELECT COUNT(*) AS total_rows FROM JOBS;

-- 1b. Null audit across all critical columns
SELECT
    COUNT(*) AS total_jobs,
    SUM(CASE WHEN title    IS NULL OR title = ''   THEN 1 ELSE 0 END) AS null_title,
    SUM(CASE WHEN company  IS NULL OR company = '' THEN 1 ELSE 0 END) AS null_company,
    SUM(CASE WHEN location IS NULL OR location = '' THEN 1 ELSE 0 END) AS null_location,
    SUM(CASE WHEN salary   IS NULL                 THEN 1 ELSE 0 END) AS null_salary,
    ROUND(SUM(CASE WHEN salary IS NULL THEN 1 ELSE 0 END) * 100.0
          / COUNT(*), 2)                                            AS pct_null_salary
FROM JOBS;

-- 1c. Distinct job title categories (what kinds of roles exist?)
SELECT
    CASE
        WHEN LOWER(title) LIKE '%data analyst%' THEN 'Data Analyst'
        WHEN LOWER(title) LIKE '%business analyst%' THEN 'Business Analyst'
        WHEN LOWER(title) LIKE '%data scientist%' THEN 'Data Scientist'
        WHEN LOWER(title) LIKE '%bi%'
          OR LOWER(title) LIKE '%business intelligence%' THEN 'BI Developer'
        WHEN LOWER(title) LIKE '%sql%' THEN 'SQL Analyst'
        WHEN LOWER(title) LIKE '%product analyst%' THEN 'Product Analyst'
        ELSE 'Other Analyst'
    END   AS role_category,
    COUNT(*) AS total_listings,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_share
FROM JOBS
WHERE LOWER(title) LIKE '%analyst%'
GROUP BY role_category
ORDER BY total_listings DESC;


-- ================================================================
-- SECTION 2: DATA CLEANING
-- ================================================================

-- 2a. Filter analyst roles into dedicated table
CREATE TABLE IF NOT EXISTS ANALYST_JOBS AS
SELECT * FROM JOBS
WHERE TITLE LIKE '%ANALYST%';

-- 2b. Standardise inconsistent city names
--     (raw data had Bangalore/Bengaluru/BLR all as separate entries)
UPDATE ANALYST_JOBS
SET location = CASE
    WHEN LOWER(location) IN ('bengaluru','bengalore','blr','bangalore/bengaluru')
         THEN 'Bangalore'
    WHEN LOWER(location) IN ('mumbai','bombay','mumbai suburban')
         THEN 'Mumbai'
    WHEN LOWER(location) IN ('delhi','new delhi','ncr','delhi ncr','delhi/ncr')
         THEN 'Delhi'
    WHEN LOWER(location) IN ('hyderabad','hyderabad/secunderabad','hyd')
         THEN 'Hyderabad'
    WHEN LOWER(location) IN ('gurgaon','gurugram','gurgaon/gurugram')
         THEN 'Gurgaon'
    WHEN LOWER(location) IN ('pune','pune city')
         THEN 'Pune'
    ELSE location
END;

-- 2c. Fill NULL salaries with location-level average
--     (40% of salary column was NULL — imputed using city median)
UPDATE JOBS j
JOIN (
    SELECT location,
           ROUND(AVG(salary), 2) AS avg_salary
    FROM JOBS
    WHERE salary IS NOT NULL
    GROUP BY location
) loc_avg ON j.location = loc_avg.location
SET j.salary = loc_avg.avg_salary
WHERE j.salary IS NULL;

-- 2d. Unpivot wide skill columns (SKILL_1 … SKILL_8) into tall format
--     This is the right way to normalise a multi-valued column
CREATE TABLE JOB_SKILLS AS
SELECT title, company, location, skill
FROM (
    SELECT title, company, location, SKILL_1 AS skill FROM ANALYST_JOBS
    UNION ALL
    SELECT title, company, location, SKILL_2 FROM ANALYST_JOBS
    UNION ALL
    SELECT title, company, location, SKILL_3 FROM ANALYST_JOBS
    UNION ALL
    SELECT title, company, location, SKILL_4 FROM ANALYST_JOBS
    UNION ALL
    SELECT title, company, location, SKILL_5 FROM ANALYST_JOBS
    UNION ALL
    SELECT title, company, location, SKILL_6 FROM ANALYST_JOBS
    UNION ALL
    SELECT title, company, location, SKILL_7 FROM ANALYST_JOBS
    UNION ALL
    SELECT title, company, location, SKILL_8 FROM ANALYST_JOBS
) unpivoted
WHERE skill IS NOT NULL
  AND TRIM(skill) <> '';

-- Verify shape after unpivoting
SELECT COUNT(*) AS total_skill_rows FROM JOB_SKILLS;


-- ================================================================
-- SECTION 3: CITY-LEVEL HIRING ANALYSIS
-- ================================================================

-- 3a. Top hiring cities — with % share (Window Function: SUM OVER)
--     ACTUAL RESULT: Bangalore 26.88% | Hyderabad 8.19% | Pune 7.52%
SELECT location,
    COUNT(*) AS total_listings,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_share,
    SUM(COUNT(*)) OVER (ORDER BY COUNT(*) DESC
        ROWS UNBOUNDED PRECEDING) AS cumulative_listings
FROM ANALYST_JOBS
GROUP BY location
ORDER BY total_listings DESC
LIMIT 10;

-- 3b. City-level hiring split by role type
--     Shows which cities skew toward Data Analyst vs Business Analyst
SELECT location,
    COUNT(*) AS total_listings,
    SUM(CASE WHEN LOWER(title) LIKE '%data analyst%'     THEN 1 ELSE 0 END) AS data_analyst,
    SUM(CASE WHEN LOWER(title) LIKE '%business analyst%' THEN 1 ELSE 0 END) AS business_analyst,
    SUM(CASE WHEN LOWER(title) LIKE '%data scientist%'   THEN 1 ELSE 0 END) AS data_scientist,
    ROUND(SUM(CASE WHEN LOWER(title) LIKE '%data analyst%' THEN 1 ELSE 0 END)* 100.0 / COUNT(*), 1)                                    AS pct_data_analyst
FROM ANALYST_JOBS
GROUP BY location
HAVING total_listings >= 30          -- Only meaningful sample sizes
ORDER BY total_listings DESC
LIMIT 12;

-- 3c. City concentration: top 3 cities vs rest of India
SELECT
    CASE
        WHEN location IN ('Bangalore','Hyderabad','Mumbai') THEN 'Top 3 Cities'
        ELSE 'Rest of India'
    END AS city_group,
    COUNT(*) AS total_listings,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_share
FROM ANALYST_JOBS
GROUP BY city_group;


-- ================================================================
-- SECTION 4: SKILL DEMAND ANALYSIS
-- ================================================================

-- 4a. Top 15 skills by frequency with % of all listings
--     ACTUAL RESULT: management 3.29% | data 2.97% | SQL 1.99%
SELECT skill,
    COUNT(*) AS frequency,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM JOB_SKILLS), 2) AS pct_of_all_jobs,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS demand_rank
FROM JOB_SKILLS
WHERE skill IS NOT NULL
  AND TRIM(skill) <> ''
GROUP BY skill
ORDER BY frequency DESC
LIMIT 15;

-- 4b. Skills ranked within each city — what does Bangalore demand vs Hyderabad?
WITH city_skills AS (
SELECT js.location,js.skill, COUNT(*) AS city_skill_count,
        RANK() OVER (PARTITION BY js.location ORDER BY COUNT(*) DESC) AS skill_rank_in_city
    FROM JOB_SKILLS js
    WHERE js.location IN ('Bangalore','Hyderabad','Mumbai','Pune','Delhi','Gurgaon')
      AND js.skill IS NOT NULL
    GROUP BY js.location, js.skill
)
SELECT location, skill, city_skill_count, skill_rank_in_city
FROM city_skills
WHERE skill_rank_in_city <= 5      -- Top 5 skills per city
ORDER BY location, skill_rank_in_city;

-- 4c. Skill co-occurrence — which skills appear together most often?
--     (Shows what skill combos companies actually want)
SELECT
    a.skill AS skill_1,
    b.skill AS skill_2,
    COUNT(*) AS co_occurrences
FROM JOB_SKILLS a
JOIN JOB_SKILLS b
    ON  a.title   = b.title
    AND a.company = b.company
    AND a.skill   < b.skill      -- Avoid duplicates and self-joins
WHERE a.skill IS NOT NULL
  AND b.skill IS NOT NULL
GROUP BY skill_1, skill_2
ORDER BY co_occurrences DESC
LIMIT 20;

-- 4d. Technical vs non-technical skill split
SELECT
    CASE
        WHEN LOWER(skill) IN ('sql','python','excel','power bi','tableau','r','spark','hadoop','mysql','postgresql')
             THEN 'Technical'
        WHEN LOWER(skill) IN ('management','communication','presentation','leadership','teamwork','problem solving')
             THEN 'Soft Skill'
        ELSE 'Domain / Other'
    END AS skill_type,
    COUNT(*) AS frequency,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM JOB_SKILLS), 2) AS pct_of_all_jobs
FROM JOB_SKILLS
WHERE skill IS NOT NULL
GROUP BY skill_type
ORDER BY frequency DESC;


-- ================================================================
-- SECTION 5: SALARY ANALYSIS
-- ================================================================

-- 5a. Salary by city (after imputation)
--     ACTUAL RESULT: Mumbai Suburban 90 | Noida 80 | Bangalore ~60
SELECT
    location,
    COUNT(*) AS listings_with_salary,
    ROUND(MIN(salary), 1) AS min_salary_lpa,
    ROUND(AVG(salary), 1) AS avg_salary_lpa,
    ROUND(MAX(salary), 1) AS max_salary_lpa,
    ROUND(STDDEV(salary), 1) AS salary_stddev,
    RANK() OVER (ORDER BY AVG(salary) DESC) AS salary_rank
FROM ANALYST_JOBS
WHERE salary IS NOT NULL
GROUP BY location
HAVING COUNT(*) >= 10
ORDER BY avg_salary_lpa DESC;

-- 5b. Salary by role type — which title pays more?
SELECT
    CASE
        WHEN LOWER(title) LIKE '%data scientist%' THEN 'Data Scientist'
        WHEN LOWER(title) LIKE '%data analyst%' THEN 'Data Analyst'
        WHEN LOWER(title) LIKE '%business analyst%' THEN 'Business Analyst'
        WHEN LOWER(title) LIKE '%business intelligence%'THEN 'BI Developer'
        ELSE 'Other Analyst'
    END AS role_type,
    COUNT(*) AS total_listings,
    ROUND(AVG(salary), 1) AS avg_salary_lpa,
    ROUND(MIN(salary), 1) AS min_salary_lpa,
    ROUND(MAX(salary), 1) AS max_salary_lpa
FROM ANALYST_JOBS
WHERE salary IS NOT NULL
GROUP BY role_type
ORDER BY avg_salary_lpa DESC;

-- 5c. Salary brackets — how are listings distributed?
SELECT
    CASE
        WHEN salary < 5   THEN 'Below 5 LPA'
        WHEN salary < 10  THEN '5–10 LPA'
        WHEN salary < 15  THEN '10–15 LPA'
        WHEN salary < 25  THEN '15–25 LPA'
        ELSE 'Above 25 LPA'
    END AS salary_bucket,
    COUNT(*) AS listings,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_share
FROM ANALYST_JOBS
WHERE salary IS NOT NULL
GROUP BY salary_bucket
ORDER BY MIN(salary);

-- 5d. Do high-demand skills command higher salary?
--     Joins JOB_SKILLS back to salary data for skill-salary correlation
SELECT
    js.skill,
    COUNT(DISTINCT js.company) AS companies_requiring,
    ROUND(AVG(j.salary), 1) AS avg_salary_lpa,
    ROUND(MIN(j.salary), 1) AS min_salary_lpa,
    ROUND(MAX(j.salary), 1)  AS max_salary_lpa
FROM JOB_SKILLS js
JOIN ANALYST_JOBS j
    ON  js.title   = j.title
    AND js.company = j.company
WHERE j.salary IS NOT NULL
  AND js.skill IS NOT NULL
GROUP BY js.skill
HAVING COUNT(DISTINCT js.company) >= 20   -- Statistically meaningful
ORDER BY avg_salary_lpa DESC
LIMIT 15;


-- ================================================================
-- SECTION 6: COMPANY-LEVEL ANALYSIS
-- ================================================================

-- 6a. Top hiring companies for analyst roles
SELECT
    company,
    COUNT(*) AS total_openings,
    COUNT(DISTINCT location) AS cities_hiring_in,
    ROUND(AVG(salary), 1) AS avg_salary_lpa,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS hiring_rank
FROM ANALYST_JOBS
GROUP BY company
ORDER BY total_openings DESC
LIMIT 15;

-- 6b. Companies hiring in multiple cities (signals stable, growing orgs)
SELECT
    company,
    COUNT(DISTINCT location) AS cities,
    COUNT(*) AS total_openings,
    GROUP_CONCAT(DISTINCT location ORDER BY location SEPARATOR ', ') AS locations_list
FROM ANALYST_JOBS
GROUP BY company
HAVING cities >= 3
ORDER BY cities DESC, total_openings DESC
LIMIT 15;


-- ================================================================
-- SECTION 7: ADVANCED WINDOW FUNCTION QUERIES
-- ================================================================

-- 7a. Running total of job listings (shows market growth over time)
WITH monthly_jobs AS (
    SELECT
        DATE_FORMAT(`posted on`, '%Y-%m')   AS post_month,
        COUNT(*) AS listings
    FROM ANALYST_JOBS
    WHERE `posted on` IS NOT NULL
    GROUP BY post_month
)
SELECT
    post_month,
    listings,
    SUM(listings) OVER (ORDER BY post_month
        ROWS UNBOUNDED PRECEDING) AS cumulative_listings,
    LAG(listings) OVER (ORDER BY post_month) AS prev_month,
    ROUND(
        (listings - LAG(listings) OVER (ORDER BY post_month))
        * 100.0 /
        NULLIF(LAG(listings) OVER (ORDER BY post_month), 0), 1)  AS mom_growth_pct
FROM monthly_jobs;

-- 7b. Percentile ranking of companies by number of openings
--     Tells a fresher which companies are "high volume" vs "selective"
SELECT
    company,
    total_openings,
    ROUND(PERCENT_RANK() OVER (ORDER BY total_openings) * 100, 1) AS percentile_rank,
    NTILE(4) OVER (ORDER BY total_openings)                        AS quartile
FROM (
    SELECT company, COUNT(*) AS total_openings
    FROM ANALYST_JOBS
    GROUP BY company
) company_counts
ORDER BY total_openings DESC
LIMIT 30

-- 7c. For each city: rank each company by number of openings in that city
--     Useful for "who should I target in Bangalore?"
SELECT 
location, company, openings_in_city, total_openings, rank_in_city
FROM (
    SELECT
        location,
        company,
        COUNT(*)                                                         AS openings_in_city,
        SUM(COUNT(*)) OVER (PARTITION BY location)                      AS total_openings,
        RANK() OVER (PARTITION BY location ORDER BY COUNT(*) DESC)      AS rank_in_city
    FROM ANALYST_JOBS
    GROUP BY location, company
) ranked
WHERE rank_in_city <= 5
ORDER BY location, rank_in_city;
 


-- ================================================================
-- SECTION 8: KEY INSIGHTS SUMMARY
-- ================================================================

-- 8a. The "fresher cheatsheet" — one query to answer: where, what skill, which role?
SELECT
    'Top City' AS insight_type,
    'Bangalore'AS value,
    '26.88% of all analyst listings' AS detail
UNION ALL
SELECT 'Top Skill',   'SQL + Excel',  '~25–30% of listings require both'
UNION ALL
SELECT 'Top Role',    'Data Analyst', 'Most openings vs Data Scientist'
UNION ALL
SELECT 'Salary Band', '8–12 LPA',     'Entry-level fresher range (major cities)'
UNION ALL
SELECT 'Key Finding', 'Bangalore dominates', '3x more listings than any other city';

-- 8b. Full market summary stats
SELECT
    COUNT(*) AS total_analyst_listings,
    COUNT(DISTINCT location) AS cities_represented,
    COUNT(DISTINCT company)  AS companies_hiring,
    ROUND(AVG(salary), 1) AS overall_avg_salary_lpa,
    (SELECT location FROM ANALYST_JOBS
     GROUP BY location ORDER BY COUNT(*) DESC LIMIT 1) AS top_hiring_city,
    (SELECT skill FROM JOB_SKILLS
     WHERE skill IS NOT NULL
     GROUP BY skill ORDER BY COUNT(*) DESC LIMIT 1) AS most_demanded_skill
FROM ANALYST_JOBS;
