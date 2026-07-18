# Project: Data Analytics in SQL - Warehouse Gold Layer

## Project Description
This project implements a robust Data Analytics pipeline using SQL to transform raw, fragmented data from CRM and ERP sources into a business-ready, high-performance Data Warehouse. By following a structured "Medallion Architecture" (Bronze, Silver, and Gold), the project ensures data quality, consistency, and analytical accessibility.

The core of this project is the **Gold Layer**, which serves as the final, analytical interface. It transforms raw transactional records into intuitive **Star Schema** structures—consisting of validated dimensions (Customers and Products) and comprehensive fact tables (Sales)—enabling seamless Business Intelligence (BI) reporting and decision-making.

## Key Features
*   **Data Quality & Cleaning:** Automated ETL procedures to handle anomalies, null values, negative metrics, and data standardization (e.g., gender, country codes).
*   **Star Schema Design:** Implementation of optimized dimensional models (dimensions and facts) to simplify complex queries and improve reporting performance.
*   **Business Intelligence KPIs:** Sophisticated SQL logic to calculate critical business metrics, including:
    *   **Customer Behavioral Analysis:** Recency, Average Order Value (AOV), and customer segmentation (VIP/Regular/New).
    *   **Product Performance Analysis:** Sales velocity, category-level revenue attribution, and performance tiering (High/Mid/Low performers).
    *   **Temporal Trend Analysis:** Year-over-Year (YoY) growth, running totals, and moving averages.
*   **Analytical Toolkit:** A modular collection of SQL scripts designed for exploratory data analysis (EDA), trend forecasting, and part-to-whole attribution.

## Purpose
The primary objective is to provide a "Single Source of Truth" for organizational data. By moving from raw, noisy operational data to clean, structured analytical views, this project empowers stakeholders to derive actionable insights, monitor operational health, and optimize business strategies through data-driven precision.
