# FHSQLMonitor
You can try the [live demo](https://tinyurl.com/yc6tc7c2), and then continue to read more about the product on my blog [SQL Server Monitoring](https://www.haurumit.dk/sql-server-monitoring)

Have fun :-)
<p>
<b>September 17, 2025: Version 2.11.0</b> with:</br>
<li>Added the "Log shipping" service and the reports "Log shipping configuration" and "Log shipping status".</li>
<li>The report "Always On performance" was previously named "Always On traffic" and now also shows Average synchronization lag.</li>
<li>The report "Database configuration" now also show State, Standby, Read only, Is parameterization forced and Always On group.</li>
<li>The "Capacity" service now also collects information about VLFs (Virtual Log Files) and show these on the report "Database size".</li>
<li>The report "Index usage" now also show indexes that has not been used at all.</li>
<li>The "Instance state" service now also collects SQL Server log records with as default a severity level equal to 17 or above.</li>
<li>The report "Statistics" now also show if the indexex are Hypothetical.</li>
<li>Reports updated to show No and Yes instead of 0/1 or False/True.</li>
<li>Fixed error where agent jobs in progress was saved as errors.</li>
</p>
<p>
<b>August 5, 2025: Version 2.9.1</b> with:</br>
<li>Fixed error when collecting database scoped configuration and some databases are not online.</li>
</p>
<p>
<b>August 5, 2025: Version 2.9.0</b> with:</br>
<li>New report "Always On configuration".</li>
<li>Added "Database scoped configuration" to the report page "Database configuration".</li>
<li>Added command line interface stored procedure dbo.fhsmSPControl to allow update and changes to Schedules, Retention and Parameters without having to do manual T-SQL Update commands.</li>
</p>
<p>
<b>July 14, 2025: Version 2.8.0</b> with:</br>
<li>The Database size report now also shows disk size and allocation usage, allowing you to see which databases and tables are using which filegroups and disks.</li>
<li>The Instance configuration report now shows whether the SQL Server edition is in Mainstream Support, Extended Support, or Unsupported.</li>
<li>Combined the 3 services Database size, Partitioned indexes and Table size into the new Capacity service</li>
<li>The Monitor status report page now also shows the duration and number of service executions in the tool itself.</li>
<li>Optimized the code to collect Agent jobs performance data.</li>
<li>Optimized the code to collect Index usage data.</li>
</p>
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
