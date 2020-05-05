using Microsoft.Azure.Cosmos;
using System;
using System.Collections.Generic;
using System.Data;
using System.Threading.Tasks;

namespace WebStoreDbGenerator.V1
{
	public class WebStoreV1Repo : WebStoreRepoBase
	{
		#region "Private fields"

		private Container _customerContainer;
		private Container _customerAddressContainer;
		private Container _customerPasswordContainer;
		private Container _productCategoryContainer;
		private Container _productContainer;
		private Container _productTagsContainer;
		private Container _productTagContainer;
		private Container _salesOrderContainer;
		private Container _salesOrderDetailContainer;

		#endregion

		#region "Properties"

		public override VersionIdentifier Version => VersionIdentifier.V1;
		public override string DatabaseName => "webstore-v1";
		public override Container CustomerContainer => this._customerContainer;
		public override Container CustomerAddressContainer => this._customerAddressContainer;
		public override Container CustomerPasswordContainer => this._customerPasswordContainer;
		public override Container ProductCategoryContainer => this._productCategoryContainer;
		public override Container ProductContainer => this._productContainer;
		public override Container ProductTagsContainer => this._productTagsContainer;
		public override Container ProductTagContainer => this._productTagContainer;
		public override Container SalesOrderContainer => this._salesOrderContainer;
		public override Container SalesOrderDetailContainer => this._salesOrderDetailContainer;

		protected override (string ContainerName, string PartitionKey)[] Containers => new[]
		{
			("customer", "/id"),
			("customerAddress", "/id"),
			("customerPassword", "/id"),
			("productCategory", "/id"),
			("product", "/id"),
			("productTag", "/id"),
			("productTags", "/id"),
			("salesOrder", "/id"),
			("salesOrderDetail", "/id"),
		};

		#endregion

		#region "Generate"

		protected override void GetContainers()
		{
			if (this._customerContainer == null)
			{
				this._customerContainer = base._database.GetContainer("customer");
				this._customerAddressContainer = base._database.GetContainer("customerAddress");
				this._customerPasswordContainer = base._database.GetContainer("customerPassword");
				this._productCategoryContainer = base._database.GetContainer("productCategory");
				this._productContainer = base._database.GetContainer("product");
				this._productTagsContainer = base._database.GetContainer("productTags");
				this._productTagContainer = base._database.GetContainer("productTag");
				this._salesOrderContainer = base._database.GetContainer("salesOrder");
				this._salesOrderDetailContainer = base._database.GetContainer("salesOrderDetail");
			}
		}

		protected override int CreateDocuments()
		{
			var tasks = new[]
			{
                new Task(new Action(() => this.CreateCustomerDocuments(0).Wait())),
                new Task(new Action(() => this.CreateCustomerAddressDocuments(1).Wait())),
                new Task(new Action(() => this.CreateCustomerPasswordDocuments(2).Wait())),
                new Task(new Action(() => this.CreateProductCategoryDocuments(3).Wait())),
                new Task(new Action(() => this.CreateProductDocuments(4).Wait())),
                new Task(new Action(() => this.CreateProductTagsDocuments(5).Wait())),
                new Task(new Action(() => this.CreateProductTagDocuments(6).Wait())),
                new Task(new Action(() => this.CreateSalesOrderDocuments(7).Wait())),
                new Task(new Action(() => this.CreateSalesOrderDetailDocuments(8).Wait())),
            };
			foreach (var task in tasks)
			{
				task.Start();
			}
			Task.WaitAll(tasks);

			return 9;
		}

		private async Task CreateCustomerDocuments(int lineIndex)
		{
			var ctr = 0;
			var elapsed = await base.TimeActionAsync(async () =>
			{
				var docs = new List<dynamic>();
				foreach (DataRow row in base._customerTable.Rows)
				{
					dynamic doc = new
					{
						id = row["CustomerId"].ToString(),
						title = row["Title"].ToString(),
						firstName = row["FirstName"].ToString(),
						lastName = row["LastName"].ToString(),
						emailAddress = row["EmailAddress"].ToString(),
						phoneNumber = row["PhoneNumber"].ToString(),
						creationDate = Convert.ToDateTime(row["CreationDate"]).ToString("s"),
                    };
					docs.Add(doc);
				}

				foreach (var d in docs)
				{
					this.WriteLine($"({++ctr}) Writing customer {d.id}", lineIndex + 2);
					await this.CustomerContainer.CreateItemAsync(d, new PartitionKey(d.id));
				}
			});
			this.WriteLine($"Generated {ctr} customer documents in {elapsed}", lineIndex + 2);
		}

		private async Task CreateCustomerAddressDocuments(int lineIndex)
		{
			var ctr = 0;
			var elapsed = await base.TimeActionAsync(async () =>
			{
				var docs = new List<dynamic>();
				foreach (DataRow row in base._customerAddressTable.Rows)
				{
					dynamic doc = new
					{
						id = row["CustomerAddressId"].ToString(),
						customerId = row["CustomerId"].ToString(),
						addressLine1 = row["AddressLine1"].ToString(),
						addressLine2 = row["AddressLine2"].ToString(),
						city = row["City"].ToString(),
						state = row["State"].ToString(),
						country = row["Country"].ToString(),
						zipCode = row["ZipCode"].ToString(),
					};
					docs.Add(doc);
				}

				foreach (var d in docs)
				{
					this.WriteLine($"({++ctr}) Writing customer address {d.id}", lineIndex + 2);
					await this.CustomerAddressContainer.CreateItemAsync(d, new PartitionKey(d.id));
				}
			});
			this.WriteLine($"Generated {ctr} customer address documents in {elapsed}", lineIndex + 2);
		}

		private async Task CreateCustomerPasswordDocuments(int lineIndex)
		{
			var ctr = 0;
			var elapsed = await base.TimeActionAsync(async () =>
			{
				var docs = new List<dynamic>();
				foreach (DataRow row in base._customerPasswordTable.Rows)
				{
					dynamic doc = new
					{
						id = row["CustomerId"].ToString(),
						hash = Convert.ToBase64String((byte[])row["Hash"]),
						salt = row["Salt"].ToString(),
					};
					docs.Add(doc);
				}

				foreach (var d in docs)
				{
					this.WriteLine($"({++ctr}) Writing customer password {d.id}", lineIndex + 2);
					await this.CustomerPasswordContainer.CreateItemAsync(d, new PartitionKey(d.id));
				}
			});
			this.WriteLine($"Generated {ctr} customer password documents in {elapsed}", lineIndex + 2);
		}

		private async Task CreateProductCategoryDocuments(int lineIndex)
		{
			var ctr = 0;
			var elapsed = await base.TimeActionAsync(async () =>
			{
				var docs = new List<dynamic>();
				foreach (DataRow row in base._productCategoryTable.Rows)
				{
					dynamic doc = new
					{
						id = row["ProductCategoryId"].ToString(),
						name = row["Name"].ToString(),
					};
					docs.Add(doc);
				}

				foreach (var d in docs)
				{
					this.WriteLine($"({++ctr}) Writing product category {d.id}", lineIndex + 2);
					await this.ProductCategoryContainer.CreateItemAsync(d, new PartitionKey(d.id));
				}
			});
			this.WriteLine($"Generated {ctr} product category documents in {elapsed}", lineIndex + 2);
		}

		private async Task CreateProductDocuments(int lineIndex)
		{
			var ctr = 0;
			var elapsed = await base.TimeActionAsync(async () =>
			{
				var docs = new List<dynamic>();
				foreach (DataRow row in base._productTable.Rows)
				{
					dynamic doc = new
					{
						id = row["ProductId"].ToString(),
						categoryId = row["ProductCategoryId"].ToString(),
						sku = row["Sku"].ToString(),
						name = row["Name"].ToString(),
						description = row["Description"].ToString(),
						price = (decimal)row["Price"],
					};
					docs.Add(doc);
				}

				foreach (var d in docs)
				{
					this.WriteLine($"({++ctr}) Writing product {d.id}", lineIndex + 2);
					await this.ProductContainer.CreateItemAsync(d, new PartitionKey(d.id));
				}
			});
			this.WriteLine($"Generated {ctr} product documents in {elapsed}", lineIndex + 2);
		}

		private async Task CreateProductTagsDocuments(int lineIndex)
		{
			var ctr = 0;
			var elapsed = await base.TimeActionAsync(async () =>
			{
				var docs = new List<dynamic>();
				foreach (DataRow row in base._productTagsTable.Rows)
				{
					dynamic doc = new
					{
						id = $"{row["ProductId"]}.{row["ProductTagId"]}",
						productId = row["ProductId"].ToString(),
						productTagId = row["ProductTagId"].ToString(),
					};
					docs.Add(doc);
				}

				foreach (var d in docs)
				{
					this.WriteLine($"({++ctr}) Writing product tags {d.id}", lineIndex + 2);
					await this.ProductTagsContainer.CreateItemAsync(d, new PartitionKey(d.id));
				}
			});
			this.WriteLine($"Generated {ctr} product tags documents in {elapsed}", lineIndex + 2);
		}

		private async Task CreateProductTagDocuments(int lineIndex)
		{
			var ctr = 0;
			var elapsed = await base.TimeActionAsync(async () =>
			{
				var docs = new List<dynamic>();
				foreach (DataRow row in base._productTagTable.Rows)
				{
					dynamic doc = new
					{
						id = row["ProductTagId"].ToString(),
						name = row["Name"].ToString(),
					};
					docs.Add(doc);
				}

				foreach (var d in docs)
				{
					this.WriteLine($"({++ctr}) Writing product tag {d.id}", lineIndex + 2);
					await this.ProductTagContainer.CreateItemAsync(d, new PartitionKey(d.id));
				}
			});
			this.WriteLine($"Generated {ctr} product tag documents in {elapsed}", lineIndex + 2);
		}

		private async Task CreateSalesOrderDocuments(int lineIndex)
		{
			var ctr = 0;
			var elapsed = await base.TimeActionAsync(async () =>
			{
				var docs = new List<dynamic>();
				foreach (DataRow row in base._salesOrderTable.Rows)
				{
					dynamic doc = new
					{
						id = row["SalesOrderId"].ToString(),
						customerId = row["CustomerId"].ToString(),
                        orderDate = Convert.ToDateTime(row["OrderDate"]).ToString("s"),
                        shipDate = Convert.ToDateTime(row["ShipDate"]).ToString("s"),
                    };
					docs.Add(doc);
				}

				foreach (var d in docs)
				{
					this.WriteLine($"({++ctr}) Writing sales order {d.id}", lineIndex + 2);
					await this.SalesOrderContainer.CreateItemAsync(d, new PartitionKey(d.id));
				}
			});
			this.WriteLine($"Generated {ctr} sales order documents in {elapsed}", lineIndex + 2);
		}

		private async Task CreateSalesOrderDetailDocuments(int lineIndex)
		{
			var ctr = 0;
			var elapsed = await base.TimeActionAsync(async () =>
			{
				var docs = new List<dynamic>();
				foreach (DataRow row in base._salesOrderDetailTable.Rows)
				{
					dynamic doc = new
					{
						id = row["SalesOrderDetailId"].ToString(),
						salesOrderId = row["SalesOrderId"].ToString(),
						sku = row["Sku"].ToString(),
						name = row["Name"].ToString(),
						price = (decimal)row["Price"],
						quantity = (short)row["Quantity"],
					};
					docs.Add(doc);
				}

				foreach (var d in docs)
				{
					this.WriteLine($"({++ctr}) Writing sales order detail {d.id}", lineIndex + 2);
					await this.SalesOrderDetailContainer.CreateItemAsync(d, new PartitionKey(d.id));
				}
			});
			this.WriteLine($"Generated {ctr} sales order detail documents in {elapsed}", lineIndex + 2);
		}

		#endregion
	}
}
