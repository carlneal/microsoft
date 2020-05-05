using Microsoft.Azure.Cosmos;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Threading.Tasks;

namespace WebStoreDbGenerator
{
	public abstract class WebStoreRepoBase
	{
		#region "Private fields"

		private readonly object _threadLock = new object();

		private static string[] _sqlTableNames = new[]
		{
			"Customer",
			"CustomerAddress",
			"CustomerPassword",
			"Product",
			"ProductCategory",
			"ProductTag",
			"ProductTags",
			"SalesOrder",
			"SalesOrderDetail",
		};

		protected Database _database;

		protected DataTable _customerTable;
		protected DataTable _customerAddressTable;
		protected DataTable _customerPasswordTable;
		protected DataTable _productTable;
		protected DataTable _productCategoryTable;
		protected DataTable _productTagTable;
		protected DataTable _productTagsTable;
		protected DataTable _salesOrderTable;
		protected DataTable _salesOrderDetailTable;

		#endregion

		#region "Properties"

		public abstract VersionIdentifier Version { get; }
		public abstract string DatabaseName { get; }
		public abstract Container CustomerContainer { get; }
		public abstract Container CustomerAddressContainer { get; }
		public abstract Container CustomerPasswordContainer { get; }
		public abstract Container ProductCategoryContainer { get; }
		public abstract Container ProductContainer { get; }
		public abstract Container ProductTagsContainer { get; }
		public abstract Container ProductTagContainer { get; }
		public abstract Container SalesOrderContainer { get; }

		public abstract Container SalesOrderDetailContainer { get; }

		protected abstract (string ContainerName, string PartitionKey)[] Containers { get; }

		#endregion

		#region "Initialize"

		public async Task InitializeDatabase()
		{
            if (!this.Confirm($"This will create the {this.DatabaseName} database. It will be deleted if it already exists."))
            {
                return;
            }

			await this.CreateDatabase();
			await this.CreateContainers();
        }

		private async Task CreateDatabase()
		{
			this.WriteLine();
			this.WriteLine($"Creating database {this.DatabaseName} (throughput = {Constants.ThroughputRUs:N0})");
			await this.DeleteDatabase(confirm: false);
			await Shared.Client.CreateDatabaseAsync(this.DatabaseName, Constants.ThroughputRUs);
			this.WriteLine("Created database");
			this.GetDatabase();
		}

		private async Task CreateContainers()
		{
			this.WriteLine();
			this.WriteLine("Creating containers");
			foreach (var container in this.Containers)
			{
				await this.CreateContainer(
					container.ContainerName,
					container.PartitionKey);
			}
			this.WriteLine($"Created containers");
		}

		protected async Task CreateContainer(string containerName, string partitionKey)
		{
			this.WriteLine($" {containerName} (partitionKey = {partitionKey})");
			var props = new ContainerProperties
			{
				Id = containerName,
				PartitionKeyPath = partitionKey,
				DefaultTimeToLive = -1,
			};
			await this._database.CreateContainerAsync(props);

			await this.OnContainerCreated(containerName);
		}

		protected virtual async Task OnContainerCreated(string containerName)
		{
		}

		protected void GetDatabase()
		{
			if (this._database == null)
			{
				this._database = Shared.Client.GetDatabase(this.DatabaseName);
			}
		}

		protected abstract void GetContainers();

        public async Task DeleteDatabase(bool confirm)
        {
            if (confirm && !this.Confirm($"This will delete the {this.DatabaseName} database, if it already exists."))
            {
                return;
            }

            var deleted = false;
            try
            {
                await Shared.Client.GetDatabase(this.DatabaseName).DeleteAsync();
                deleted = true;
            }
            catch (Exception ex)
            {
                this.WriteLine($"Could not delete database {this.DatabaseName}: {ex.Message}");
            }
            if (deleted)
            {
                this.WriteLine($"Deleted database {this.DatabaseName}");
            }
        }

		#endregion

		#region "Generate"

		public void GenerateData()
		{
			this.GetDatabase();
			this.GetContainers();

			this.WriteLine("Loading SQL Server tables");
			this.LoadSqlTables();

			Console.Clear();
			this.WriteLine("Generating JSON documents");

			var elapsed = this.TimeAction(() =>
			{
				var lineIndex = this.CreateDocuments();
				Console.SetCursorPosition(0, lineIndex + 3);
			});

			this.WriteLine($"Done; total elapsed: {elapsed}");
		}

		protected abstract int CreateDocuments();

		#endregion

		#region "Change product category and/or tag name (change feed)"

		public async Task ChangeProductCategoryName()
		{
			this.GetDatabase();
			this.GetContainers();
			var name = await this.ChangeProductRelatedName(this.ProductCategoryContainer, "category");
			this.WriteLine($"Updated category 1 ID name as '{name}'");
		}

		public async Task ChangeProductTagName()
		{
			this.GetDatabase();
			this.GetContainers();
			var name = await this.ChangeProductRelatedName(this.ProductTagContainer, "tag");
			this.WriteLine($"Updated tag ID 1 name as '{name}'");
		}

		private async Task<string> ChangeProductRelatedName(Container container, string partitionKey)
		{
			var doc = (await (container.ReadItemAsync<dynamic>("1", new PartitionKey(partitionKey)))).Resource;

			string name = doc.name;
			doc.name = name.Split(" @")[0] + " @ " + DateTime.Now.ToString();

			await container.ReplaceItemAsync(doc, "1");

			return doc.name;
		}

		#endregion

		#region "Create new sales order (stored procedure)"

		public async Task CreateSalesOrder()
		{
			this.GetDatabase();
			this.GetContainers();

			var sql = $"SELECT TOP 1 * FROM c WHERE c.type = 'salesOrder' AND c.customerId = '11000'";
			var options = new QueryRequestOptions { MaxConcurrency = -1 };
			var iterator = this.CustomerContainer.GetItemQueryIterator<dynamic>(sql, requestOptions: options);
			var salesOrder = (await iterator.ReadNextAsync()).First();
			salesOrder.id = Guid.NewGuid().ToString();

			this.WriteLine($"Calling stored procedure to create new sales order and update customer");
			var response = await this.CustomerContainer.Scripts.ExecuteStoredProcedureAsync<int>("spCreateSalesOrder", new PartitionKey("11000"), new[] { salesOrder });
			var newSalesOrderCount = response.Resource;
			this.WriteLine($"Stored procedure was successful; new sales order count = '{newSalesOrderCount}'");
		}

		#endregion

		#region "SQL Server"

		private void LoadSqlTables()
		{
			var dict = new Dictionary<string, DataTable>();
			Parallel.ForEach(_sqlTableNames, (sqlTableName) =>
			{
				var table = this.LoadSqlTable(sqlTableName);
				dict.Add(sqlTableName, table);
			});

			this._customerTable = dict["Customer"];
			this._customerAddressTable = dict["CustomerAddress"];
			this._customerPasswordTable = dict["CustomerPassword"];
			this._productTable = dict["Product"];
			this._productCategoryTable = dict["ProductCategory"];
			this._productTagTable = dict["ProductTag"];
			this._productTagsTable = dict["ProductTags"];
			this._salesOrderTable = dict["SalesOrder"];
			this._salesOrderDetailTable = dict["SalesOrderDetail"];
		}

		private DataTable LoadSqlTable(string tableName)
		{
			var dt = new DataTable();
			using (var conn = new SqlConnection(Shared.WebStoreDbConnStr))
			{
				conn.Open();
				using (var cmd = conn.CreateCommand())
				{
					cmd.CommandText = $"SELECT * FROM [{tableName}]";
					using (var adp = new SqlDataAdapter(cmd))
					{
						adp.Fill(dt);
					}
				}
			}
			this.WriteLine($" Loaded {dt.Rows.Count} rows from {tableName} table");
			return dt;
		}

		#endregion

		#region "Helpers"

		protected TimeSpan TimeAction(Action method)
		{
			var started = DateTime.Now;
			method();
			var elapsed = DateTime.Now.Subtract(started);

			return elapsed;
		}

		protected async Task<TimeSpan> TimeActionAsync(Func<Task> method)
		{
			var started = DateTime.Now;
			await method();
			var elapsed = DateTime.Now.Subtract(started);

			return elapsed;
		}

		protected void WriteLine(string line = null, int? lineNumber = null)
		{
			lock (_threadLock)
			{
				if (lineNumber != null)
				{
					Console.SetCursorPosition(0, lineNumber.Value);
				}
				if (line == null)
				{
					Console.WriteLine();
				}
				else
				{
					Console.WriteLine($"[{this.Version} {DateTime.Now:MM/dd/yyyy HH:mm:ss}] {line}");
				}
			}
		}

		private bool Confirm(string message)
		{
			Console.WriteLine(message);
			while (true)
			{
				Console.Write("Are you sure (Y/N)? ");
				var input = Console.ReadLine();
				if (input.ToLower().StartsWith("y"))
				{
					return true;
				}
				if (input.ToLower().StartsWith("n"))
				{
					return false;
				}
			}
		}

		#endregion

	}
}
