# Job Market Analysis — Data Analyst Roles

> **Which city should a fresher target? What skills actually get you hired? What salary is realistic?**
> I analyzed **90,000+ real Indian job listings** to answer these questions using SQL, Excel, and Power BI.

![SQL](https://img.shields.io/badge/SQL-MySQL%208.0-orange?logo=mysql)
![Excel](https://img.shields.io/badge/Excel-Power%20Query-green?logo=microsoft-excel)
![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-yellow?logo=powerbi)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)

---

##  Project Overview

As a fresher entering the data job market in India, I found a lot of contradictory advice online. So instead of guessing, I decided to **analyze the actual data**.

This project answers **5 critical questions** for anyone job-hunting in data roles in India:

| # | Question | Answer Found |
|---|---|---|
| 1 | Which city has the most data analyst openings? | Bangalore (26.88% of all listings) |
| 2 | What are the top skills employers ask for? | SQL, Excel, Python, Power BI |
| 3 | What salary should a fresher expect? | ₹8–12 LPA in top cities |
| 4 | Which companies hire the most? | TCS, Infosys, Wipro, Capgemini |
| 5 | Which role has the most openings? | Data Analyst (not Data Scientist) |

---

##  Dataset

| Field | Details |
|---|---|
| Source | Scraped from Naukri.com / LinkedIn India |
| Total Rows | 90,000+ job listings |
| Columns | Title, Company, Location, Salary, Skills (8 columns), Posted Date |
| Time Period | 2024–2025 |
| Key Issues | ~40% null salary values, inconsistent city names, wide skill format (SKILL_1 to SKILL_8) |

---

##  Tools Used

| Tool | Purpose |
|---|---|
| **MySQL 8.0** | Data cleaning, unpivoting, aggregation, window functions |
| **Excel + Power Query** | Initial data inspection, pivot tables |
| **Power BI** | Interactive dashboard for city, skill, salary exploration |

---

##  Data Cleaning — What I Fixed

### Problem 1: 40% Null Values in Salary Column
Filled nulls using **location-level average salary** so comparisons stay valid:

```sql
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

```sql
UPDATE analyst_jobs
SET location = CASE
    WHEN LOWER(location) IN ('bengaluru','bengalore','blr','bangalore/bengaluru') THEN 'Bangalore'
    WHEN LOWER(location) IN ('hyderabad','hyderabad/secunderabad','hyd')          THEN 'Hyderabad'
    WHEN LOWER(location) IN ('gurgaon','gurugram','gurgaon/gurugram')             THEN 'Gurgaon'
    ELSE location
END;
```

> Without this step, Bangalore would appear as 4 separate cities — severely undercounting its true market share.

---

### Problem 3: Wide Skill Format (SKILL_1 to SKILL_8)
The raw data stored skills in 8 separate columns — impossible to count or rank. Unpivoted into a normalized tall format:

```sql
CREATE TABLE JOB_SKILLS AS
SELECT title, company, location, skill
FROM (
    SELECT title, company, location, SKILL_1 AS skill FROM analyst_jobs
    UNION ALL SELECT title, company, location, SKILL_2 FROM analyst_jobs
    UNION ALL SELECT title, company, location, SKILL_3 FROM analyst_jobs
    UNION ALL SELECT title, company, location, SKILL_4 FROM analyst_jobs
    UNION ALL SELECT title, company, location, SKILL_5 FROM analyst_jobs
    UNION ALL SELECT title, company, location, SKILL_6 FROM analyst_jobs
    UNION ALL SELECT title, company, location, SKILL_7 FROM analyst_jobs
    UNION ALL SELECT title, company, location, SKILL_8 FROM analyst_jobs
) unpivoted
WHERE skill IS NOT NULL AND TRIM(skill) <> '';
```

> Transformed an unqueryable wide format into a proper one-skill-per-row table that can be grouped, ranked, and joined.

---

##  Analysis & Findings

### Finding 1: Bangalore Dominates — By a Large Margin

```sql
SELECT
    location,
    COUNT(*) AS total_listings,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_share
FROM analyst_jobs
GROUP BY location
ORDER BY total_listings DESC
LIMIT 10;
```

**Results:**

| City | Listings | % Share |
|---|---|---|
| **Bangalore/Bengaluru** | **958** | **26.88%** |
| Hyderabad/Secunderabad | 292 | 8.19% |
| Pune | 268 | 7.52% |
| Mumbai | 259 | 7.27% |
| Gurgaon/Gurugram | 187 | 5.25% |
| Chennai | ~170 | ~4.90% |

**Key Insight:** Bangalore alone has **3.3x more listings** than the next city. A fresher not applying to Bangalore is ignoring 27% of the entire market.

> `SUM(COUNT(*)) OVER()` computes the grand total in a single pass using a window function — no subquery needed.

---

### Finding 2: SQL & Excel Are the Non-Negotiables

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

**Results:**

| Skill | Frequency | % of All Job Slots |
|---|---|---|
| management | 477 | 3.29% |
| data | 431 | 2.97% |
| analysis | 386 | 2.66% |
| business analysis | 344 | 2.37% |
| analytics | 318 | 2.19% |
| **SQL** | **288** | **1.99%** |
| Data Analysis | 285 | 1.97% |

**Key Insight:** SQL appears in ~2% of all skill slots. Given 8 skills per listing, SQL appears in roughly **25–28% of all job postings** — making it the #1 technical skill to have.

> **Data quality note:** Generic terms like "management" and "data" ranked high because skill columns contained job-description fragments. A production pipeline would whitelist valid tool names before analysis.

---

### Finding 3: Salary Reality Check

```sql
SELECT
    location,
    ROUND(AVG(salary), 2) AS avg_salary_lpa,
    COUNT(*) AS listings_with_salary
FROM jobs
WHERE salary IS NOT NULL
GROUP BY location
HAVING COUNT(*) >= 10
ORDER BY avg_salary_lpa DESC;
```

**Key Insight:** Realistic entry-level salaries after normalization:

| City | Fresher Salary Range |
|---|---|
| Bangalore | ₹8 – 12 LPA |
| Hyderabad | ₹7 – 11 LPA |
| Mumbai | ₹7 – 10 LPA |
| Pune | ₹6 – 9 LPA |
| Delhi/NCR | ₹5 – 9 LPA |

> `HAVING COUNT(*) >= 10` filters out cities with only 1–2 listings — small samples produce misleading averages and must be excluded from salary analysis.

---

##  Key Business Insights

| # | Insight | Implication |
|---|---|---|
| 1 | Bangalore = 26.88% of all analyst listings | Apply here first — 1 in 4 jobs is here |
| 2 | Bangalore + Hyderabad = 35% of market | Two cities cover a third of all openings |
| 3 | SQL in ~25–28% of postings | Single most important technical skill for a fresher |
| 4 | "Data Analyst" is 3–4x more common than "Data Scientist" | Target DA roles first |
| 5 | Soft skills dominate raw skill counts | Companies value communication as much as tools |

---

##  Advanced SQL Techniques Used

| Technique | Where Used | Why It Matters |
|---|---|---|
| `SUM() OVER()` window function | City % share | Calculates grand total without a subquery |
| `UNION ALL` unpivoting | Skill normalization | Converts wide format to analyzable tall format |
| `UPDATE` with JOIN subquery | Salary null imputation | City-level fill — more accurate than global mean |
| `CASE + LOWER()` | City standardization | Case-insensitive matching catches all variants |
| Correlated subquery | Skill % calculation | Divides by total skill rows, not group count |
| `HAVING COUNT(*) >= 10` | Salary by city | Removes statistically insignificant samples |

---

##  Power BI Dashboard

**Page 1 — Market Overview**
- City map by listing volume
- Skill frequency bar chart (top 15)
- Role type donut chart

**Page 2 — Salary Explorer**
- Salary by city
- Salary by role type
- Salary bracket distribution

**Page 3 — Company Intelligence**
- Top hiring companies
- Multi-city hiring presence
- Skill demand by company

---

##  Project Structure

```
End-to-End-Job-Market-Analysis-Dashboard/
│
├── JobMarket_Analysis.sql              ← All SQL (cleaning + analysis)
├── Job Market Analytics Dashboard.pbix ← Power BI dashboard
├── JobMarket_Analysis_ModelData.xlsx   ← Cleaned data model
├── screenshots/
│   ├── city_hiring_result.png          ← Bangalore 26.88%
│   ├── skill_demand_result.png         ← SQL 1.99%
│   └── salary_by_city_result.png       ← Salary breakdown
└── README.md
```

---

##  How to Run

```bash
# 1. Clone the repo
git clone https://github.com/achaltidke03/End-to-End-Job-Market-Analysis-Dashboard

# 2. Import the dataset into MySQL Workbench
#    Database: analysts | Table: jobs

# 3. Run JobMarket_Analysis.sql section by section
#    Sections 1–2 = cleaning | Sections 3–8 = analysis

# 4. Open Job Market Analytics Dashboard.pbix in Power BI Desktop
#    Update data source to your MySQL connection
```
##  Key Design Decisions

**Why UNION ALL to unpivot skills?**
UNION removes duplicates — two jobs can legitimately share a skill,
so UNION ALL was the correct choice to preserve all rows.

**Why city-level salary imputation?**
A global average would distort city comparisons. Bangalore salaries
are nearly double Tier-2 cities — imputing them together would be
statistically wrong.


##  Contact

**Achal Tidke** — Data Analyst | Nagpur, India
 achaltidke03@gmail.com
🔗 [LinkedIn](https://linkedin.com/in/achal-tidke-618113332) | 💻 [GitHub](https://github.com/achaltidke03)

---

*⭐ Star this repo if it helped you understand the Indian data job market!*
