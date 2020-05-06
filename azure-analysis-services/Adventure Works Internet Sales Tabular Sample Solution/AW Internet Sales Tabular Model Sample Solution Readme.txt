This Analysis Services Tabular model sample solution is provided without warranty.

This solution is a completed version of the Adventure Works Internet Sales sample tabular model you can complete yourself by following steps in the Tabular Modeling tutorial at: https://msdn.microsoft.com/en-us/library/hh231691.aspx  


Requirements:

- The latest version of SQL Server Data Tools. 
Download from: https://msdn.microsoft.com/en-us/library/mt204009.aspx

- AdventureWorksDW2014 sample database installed on a SQL Server 2014 or 2016 instance. This database serves as the datasource. 
Download from: https://msftdbprodsamples.codeplex.com/releases/view/125550

- To deploy your sample model, a SQL Server 2014, 2016 Analysis Services or Azure Analysis Services instance in Tabular mode is required. 

- Admin permissions on the Analysis Services instance. 

You may need to specify connection string and Impersonation Mode user credentials to connect to the AdventureWorksDW2014 datasource: 

- To specify a different server (other than localhost) in the connection string, in the AW Internet Sales Tabular model project open in SSDT, click Model > Existing Connections > Edit > Build. In the Data Link Properties dialog, select the server instance where you installed the AdventureWorksDW2014 sample database.

- To specify Impersonation Mode credentials, in the AW Internet Sales Tabular model project open in SSDT, click Model > Existing Connections > Edit > Impersonation. In the Impersonation Information dialog, select Specific Windows user name and password, then enter credentials with permissions to import and refresh data from the AdventureWorksDW2014 datasource.


 