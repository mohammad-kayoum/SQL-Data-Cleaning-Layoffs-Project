/*
================================================================
DATA CLEANING PROJECT: WORLD LAYOFFS DATASET
Author: [Mohammad Kayoum]
Tool: MySQL Workbench
Description: This script performs end-to-end data cleaning 
including removing duplicates, standardizing strings, 
fixing date formats, and handling missing values.
================================================================
*/

-- 1. DATABASE & TABLE SETUP
CREATE DATABASE IF NOT EXISTS world_layoffs;
USE world_layoffs;

-- Create a staging table (copy of raw data) to protect the original source
CREATE TABLE layoffs_staging LIKE layoffs;
INSERT INTO layoffs_staging SELECT * FROM layoffs;

-- 2. REMOVING DUPLICATES
-- Using ROW_NUMBER() to identify identical records based on all key columns
CREATE TABLE `layoffs_cleaned` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO layoffs_cleaned 
SELECT *,
ROW_NUMBER() OVER(
    PARTITION BY company, location, industry, total_laid_off, 
                 percentage_laid_off, `date`, stage, country
) AS row_num
FROM layoffs_staging;

-- Delete rows where row_num > 1 (these are the duplicates)
DELETE FROM layoffs_cleaned WHERE row_num > 1;


-- 3. STANDARDIZING DATA
-- Trimming whitespace from company names
UPDATE layoffs_cleaned SET company = TRIM(company);

-- Consolidating industry names (e.g., merging all 'Crypto' variants)
UPDATE layoffs_cleaned 
SET industry = 'Crypto' 
WHERE industry LIKE 'Crypto%';

-- Standardizing country names (removing trailing periods/dots)
UPDATE layoffs_cleaned 
SET country = TRIM(TRAILING '.' FROM country) 
WHERE country LIKE 'United States%';


-- 4. FIXING DATE FORMATS
-- Converting the text 'date' column to a standard MySQL DATE format
UPDATE layoffs_cleaned 
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

-- Changing column type from TEXT to DATE permanently
ALTER TABLE layoffs_cleaned MODIFY COLUMN `date` DATE;


-- 5. HANDLING NULL & BLANK VALUES
-- Converting blank strings to NULL for consistent processing
UPDATE layoffs_cleaned SET industry = NULL WHERE industry = '';
UPDATE layoffs_cleaned SET industry = NULL WHERE industry = 'null';

-- Populate missing industry values by joining with other rows of the same company
UPDATE layoffs_cleaned t1
JOIN layoffs_cleaned t2 ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL 
AND t2.industry IS NOT NULL;


-- 6. FINAL DATA PRUNING
-- Dropping the helper column used for duplicate removal
ALTER TABLE layoffs_cleaned DROP COLUMN row_num;

-- Removing records that lack critical analysis data (useless rows)
DELETE FROM layoffs_cleaned
WHERE total_laid_off IS NULL 
AND percentage_laid_off IS NULL;

-- Final View of Cleaned Data
SELECT * FROM layoffs_cleaned;
