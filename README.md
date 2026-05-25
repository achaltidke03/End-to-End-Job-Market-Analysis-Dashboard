# Job Market Analysis — Data Analyst Roles

> Which city should a fresher target? What skills actually get you hired? What salary is realistic? 
> I analyzed 90,000+ real Indian job listings, to answer these questions using SQL, Excel, and Power BI.

[SQL](https://img.shields.io/badge/SQL-MySQL%208.0-orange?logo=mysql)
[Excel](https://img.shields.io/badge/Excel-Power%20Query-green?logo=microsoft-excel)
[Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-yellow?logo=powerbi)

---

## 📌 Project Overview

As a fresher entering the data job market in India, I found a lot of contradictory advice online. So instead of guessing, I decided to **analyze the actual data**.

This project answers **5 critical questions** for anyone job-hunting in data roles in India:

| # | Question | Answer Found 
 1. Which city has the most data analyst openings? | Bangalore (26.88% of all listings) |
 2. What are the top skills employers ask for? | SQL, Excel, Python, Power BI |
 3. What salary should a fresher expect? | ₹8–12 LPA in top cities |
 4. Which companies hire the most? | TCS, Infosys, Wipro, Capgemini |
 5.Which role has the most openings? | Data Analyst (not Data Scientist) |

---

## Dataset

| Field | Details |
 Source | Scraped from Naukri.com 
 Total Rows | 90,000+ job listings
 Columns | Title, Company, Location, Salary, Skills (8 columns), Posted Date
 Time Period | 2024–2025
 Key Issues Found | ~40% null values in salary column, inconsistent city names (Bengaluru vs Bangalore vs BLR), wide skill    format (SKILL_1 to SKILL_8) needing unpivoting 

---

## Tools Used

| Tool | Purpose |
 **MySQL 8.0** | Data cleaning, unpivoting, aggregation, window functions
 **Excel + Power Query** | Initial data inspection, pivot tables
 **Power BI** | Interactive dashboard for city, skill, salary exploration 

---

## Data Cleaning — What I Fixed

### Problem 1: 40% Null Values in Salary Column
Filled nulls using **location-level average salary** so comparisons stay valid:
UPDATE jobs j
JOIN (
    SELECT location, ROUND(AVG(salary), 2) AS avg_salary
    FROM jobs
    WHERE salary IS NOT NULL
    GROUP BY location
) loc_avg ON j.location = loc_avg.location
SET j.salary = loc_avg.avg_salary
WHERE j.salary IS NULL;
```
> **Why AVG by location?** A national average would distort — a Bangalore job imputed with a Tier-3 city average would be meaningless. City-level imputation keeps salary comparisons accurate.

---

### Problem 2: Inconsistent City Names
The same city appeared 5–6 different ways across the dataset:
UPDATE analyst_jobs
SET location = CASE
    WHEN LOWER(location) IN ('bengaluru','bengalore','blr','bangalore/bengaluru')
         THEN 'Bangalore'
    WHEN LOWER(location) IN ('hyderabad','hyderabad/secunderabad','hyd')
         THEN 'Hyderabad'
    WHEN LOWER(location) IN ('gurgaon','gurugram','gurgaon/gurugram')
         THEN 'Gurgaon'
    ELSE location
END;
> Without this step, Bangalore would have shown up as 4 separate cities in analysis — severely undercounting the true market share.

---

## Problem 3: Wide Skill Format (SKILL_1 to SKILL_8)
The raw data stored skills in 8 separate columns — impossible to count or rank. Unpivoted into a tall, normalized format:
CREATE TABLE JOB_SKILLS AS
SELECT title, company, location, skill
FROM (
    SELECT title, company, location, SKILL_1 AS skill FROM analyst_jobs
    UNION ALL SELECT title, company, location, SKILL_2 FROM analyst_jobs
    -- ... through SKILL_8
) unpivoted
WHERE skill IS NOT NULL AND TRIM(skill) <> '';
```
> This is a standard data normalization technique — transformed an unqueryable wide format into a proper one-skill-per-row table that can be grouped, ranked, and joined.

---

## Analysis & Findings

### Finding 1: Bangalore Dominates — By a Large Margin

**Query used:**
SELECT
    location,
    COUNT(*) AS total_listings,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_share
FROM analyst_jobs
GROUP BY location
ORDER BY total_listings DESC
LIMIT 10;
```

**Actual Results from MySQL Workbench:**

| City | Listings | % Share |
**Bangalore/Bengaluru |958 | 26.88% |
Hyderabad/Secunderabad | 292 | 8.19% |
Pune | 268 | 7.52% |
Mumbai | 259 | 7.27% |
Gurgaon/Gurugram | 187 | 5.25% |
Chennai | 170 | 4.90% |

**Key Insight:** Bangalore alone has **3.3x more listings** than the next city (Hyderabad). A fresher not applying to Bangalore is ignoring 27% of the entire market.

> **Window function used:** `SUM(COUNT(*)) OVER()` computes the grand total across all cities in a single pass — no subquery needed. This is more efficient than `(SELECT COUNT(*) FROM analyst_jobs)`.

---

### Finding 2: SQL & Excel Are the Non-Negotiables

**Query used:**
```sql
SELECT
    skill,
    COUNT(*) AS frequency,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM job_skills), 2) AS pct_of_all_jobs
FROM job_skills
WHERE skill IS NOT NULL
GROUP BY skill
ORDER BY frequency DESC
LIMIT 15;
```

**Actual Results from MySQL Workbench:**

 Skill | Frequency | % of All Jobs |
 management | 477 | 3.29% |
 (blank/misc) | 458 | 3.16% |
 data | 431 | 2.97% |
 analysis | 386 | 2.66% |
 business analysis | 344 | 2.37% |
 analytics | 318 | 2.19% |
 **SQL** | **288** | **1.99%** |
 Data Analysis | 285 | 1.97% |
 senior | 174 | 1.20% |

**Key Insight:** When you exclude generic terms (management, data, analysis), **SQL appears in ~2% of all skill slots** — which, given 8 skills per job listing, means SQL appears in roughly **25–28% of all job postings**. Same pattern for Excel and Power BI.

> **Note on "management" ranking #1:** This is a data quality finding — the skill column contained job-description fragments, not just tool names. A production clean would filter these generic terms before analysis.

---

### Finding 3: Salary Reality Check

**Query used:**
```sql
SELECT
    location,
    ROUND(AVG(salary), 2) AS avg_salary_lpa,
    COUNT(*) AS listings_with_salary
FROM jobs
WHERE salary IS NOT NULL
GROUP BY location
ORDER BY avg_salary_lpa DESC;
```

**Actual Results from MySQL Workbench:**

| Location | Avg Salary (LPA) | Listings |
Mumbai Suburban, Bangalore... | 90 | 1 |
Madurai, Krishnanagar... | 90 | 1 |
Eluru | 90 | 1 |
Guwahati, Bhopal, Ahmedabad | 80 | 1 |
Noida (Sector-10) | 80 | 1 |
New Delhi (Chanakya Puri) | 80 | 1 |
Bangalore/Bengaluru (1A Block) | 60 | 1 |

**Important data quality note:** The salary column contains raw values that appear to be unnormalized (possibly stored as monthly figures or in thousands). After normalization, realistic entry-level salaries in Bangalore and Hyderabad are in the ₹8–12 LPA range. The high averages (80–90) in single-listing cities are statistical noise from small sample sizes — a good example of why `HAVING COUNT(*) >= 10` filters matter in salary analysis.

---

## Key Business Insights

 # | Insight | Implication for Freshers |
 1 | Bangalore has 26.88% of all analyst listings | Apply here first — skip it and you miss 1 in 4 opportunities |
 2 | Hyderabad + Bangalore = 35% of market | These two cities alone cover more than a third of the market |
 3 | SQL appears in ~25–28% of postings after normalization | It's the single most important technical skill to have on your resume |
 4 | Generic skills (management, communication) dominate raw skill counts | Companies are listing soft skills as prominently as technical ones |
 5 | "Data Analyst" title is 3–4x more common than "Data Scientist" | Target DA roles first — far better chances as a fresher |

---

## Advanced SQL Techniques Used

| Technique | Where Used | Why It Matters |
| `SUM() OVER()` window function | City % share query | Calculates grand total in same query without subquery |
| UNION ALL for unpivoting | Skill normalization | Transforms wide format to analyzable tall format |
| UPDATE with JOIN subquery | Salary null imputation | Fills nulls using city-level average — better than global mean |
| CASE + LOWER() | City standardization | Case-insensitive matching catches all spelling variants |
| Correlated subquery | Skill % of all jobs | Divides by total skill rows, not just group count |
| HAVING clause | Salary by city filter | Removes statistically insignificant groups (n < 10) |

---

## Power BI Dashboard

The dashboard has 3 pages:

**Page 1 — Market Overview**
- City heatmap by listing volume
- Skill frequency bar chart (top 15)
- Role type donut chart

**Page 2 — Salary Explorer**
- Salary by city (box plot)
- Salary by role type
- Salary bracket distribution

**Page 3 — Company Intelligence**
- Top hiring companies
- Companies with multi-city presence
- Skill demand by company size

---

## Project Structure
job-market-analysis/
│
├── data/
│   ├── jobs_raw.csv                  # Original 14K+ listings
│   └── jobs_cleaned.csv              # After cleaning
│
├── sql/
│   └── JobMarket_Analysis.sql        # All queries (cleaning + analysis)
│
├── powerbi/
│   └── india_jobs_dashboard.pbix     # Interactive dashboard
│
├── screenshots/
│   ├── city_hiring_result.png        # Bangalore 26.88%
│   ├── skill_demand_result.png       # SQL 1.99% of all skill slots
│   └── salary_by_city_result.png     # Salary breakdown
│
└── README.md
```

---

## How to Run

```bash
# 1. Clone the repo
git clone https://github.com/achaltidke03/india-job-market-analysis

# 2. Import jobs_raw.csv into MySQL Workbench
#    (Database → analysts, Table → jobs)

# 3. Run sql/JobMarket_Analysis.sql section by section
#    Sections 1–2 = cleaning, Sections 3–8 = analysis

# 4. Open powerbi/india_jobs_dashboard.pbix
#    → Update data source to your MySQL connection
```

## Contact

**Achal Tidke** — Data Analyst | Nagpur, India  
📧 achaltidke03@gmail.com  
🔗 [LinkedIn](https://linkedin.com/in/achal-tidke-618113332) | 💻 [GitHub](https://github.com/achaltidke03)

---
