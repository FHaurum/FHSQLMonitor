# FHSQLMonitor
You can try the [live demo](https://app.powerbi.com/view?r=eyJrIjoiMDQ2MDQ3ZjQtOGY1Ni00N2UzLTgzOTQtYTliMTkwMDkyZjk5IiwidCI6IjczYzA3MDE0LTAyYzEtNDVkMy04NWFiLTI0NDA1MzU3ZDUyYSIsImMiOjl9), and then conitue to read more about the product on my blog [SQL Server Monitoring](https://www.haurumit.dk/sql-server-monitoring)

Have fun :-)
<p>
<b>June 9, 2025: Version 2.7.0</b> with:</br>
<li>Slicers configured as dropdown and with multi-select now has the option "Select all" enabled.</li>
<li>All filter panels reviewed and fixed for minor configuration errors.</li>
<li>Added "Fulltext" and "Other" as file types used as dimensions for "Database IO" and "Database size".</li>
<li>Added filters to the "Monitor status" report page.</li>
</p>
<p>
<b>May 25, 2025: Version 2.6.1</b> with:</br>
<li>Reverted setting "Select all" on slicers as it had side effects.</li>
</p>
<p>
<b>May 25, 2025: Version 2.6.0</b> with:</br>
<li>Optimized the "Blocks and deadlocks" report with added drill-through pages, and with info views in the framework to easily get the underlying XML documents</li>
<li>Performance update on the view queries to improve report refresh</li>
<li>Changed the report to not allow empty parameters and use default values as it resulted in dynamic queries that prevented data refresh from Power BI services</li>
</p>
<p>
<b>May 4, 2025: Version 2.5.0</b> with:</br>
<li>New report "Blocks and deadlocks"</li>
<li>Updated all pages to use 1920:1080 instead of 1280:720</li>
</p>
<p>
<b>April 15, 2025: Version 2.4.0</b> with:</br>
<li>Updated the report "Agent jobs performance" and the way the visuals interact</li>
<li>General performance update of model, measures, data and visuals</li>
</p>
<p>
<b>April 6, 2025: Version 2.3.0</b> with:</br>
<li>New report "Agent jobs performance"</li>
<li>Changed history tooltips on "Database configuration" and "Instance configuration" to be drill-through pages</li>
</p>
<p>
<b>March 30, 2025: Version 2.2.2</b> fixing an error introduced in version 2.2.0 regarding calculating data and index space used by tables.
</p>
<p>
<p>
<b>March 30, 2025: Version 2.2.1</b> fixing an error introduced in version 2.2.0 regarding calculating number of rows in tables.
</p>
<p>
<b>March 29, 2025: Version 2.2.0</b> with:</br>
<li>New report "Index configuration"</li>
<li>Corrected minor issues in the "Index usage" service</li>
<li>Update of the existing service and report "Missing indexes" to use a new SQL2019+ DMV</li>
</p>
<p>
<b>March 7, 2025: Version 2.1.0</b> with the new service "Partitioned indexes", as well as improved the installation script.
</p>
<p>
<b>March 3, 2025: Version 2.0.0</b> with a completely redesigned Power BI report and added ability to specify which of the collected data should be loaded into the report and presented.
</p>
<p>
<b>May 1, 2022: Version 1.10.0</b> of Power BI desktop report has been updated with Resource Governor reports.
</p>
<p>
<b>February 19, 2022: Version 1.9.1</b> of Power BI desktop report has the Backup Status report updated.
</p>
<p>
<b>January 25, 2022: Version 1.9.0</b> of Power BI desktop report has been updated with Agent jobs, Plan cache usage, Plan guides and Triggers reports.
</p>
<p>
<b>August 29, 2021: Version 1.7.0</b> of Power BI desktop report has been updated with support for SQL2008R2.
</p>
<p>
<b>May 17, 2021: Version 1.6.0</b> of Power BI desktop report has been updated with "Dump files" and "Suspect pages" on Instance State report and errors fixed.
</p>
<p>
<b>May 3, 2021: Version 1.5.1</b> of Power BI desktop report has been updated with Backup Status report, added IsHypothetical on Statistics Age report and errors fixed.
</p>
<p>
<b>March 24, 2021: Version 1.4.0</b> of Power BI desktop report has been updated with incremental statistics table on Statistics Age report, added RCSI on Instance State report and errors fixed.
</p>
<p>
<b>January 24, 2021: Version 1.3.0</b> of Power BI desktop report has been updated with IO latency instead of IO stall, PLE per numa node and Always ON traffic report page.
</p>
<p>
<b>November 22, 2020: Version 1.2.0</b> of Power BI desktop report has been updated with buttons on report pages allowing the select the dimension level used by the tooltip popups.
</p>
<p>
<b>November 13, 2020: Version 1.1.2</b> of Power BI desktop report has been updated with visual zoom sliders.
</p>
<p>
<b>November 12, 2020: Version 1.1.1</b> of Power BI desktop report has been updated with visual header help, trend lines, ...
</p>
<p>
<b>October 23, 2020: Version 1.1</b> has been released and it contains more features and reports, error changes as well as improved reports.
</p>
<p>
This project is a SQL Server Monitoring tool that can easily be installed on a single SQL server instance, helping to monitor the state of it.
</p>
