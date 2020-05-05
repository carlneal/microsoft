using WebStoreDbGenerator.V3;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Cosmos.Scripts;
using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace WebStoreDbGenerator.V4
{
	public class WebStoreV4Repo : WebStoreV3Repo
	{
		#region "Private fields"

		private Container _productMetaContainer;

		#endregion

		#region "Properties"

		public override VersionIdentifier Version => VersionIdentifier.V4;
		public override string DatabaseName => "webstore-v4";
		public override Container ProductCategoryContainer => this._productMetaContainer;
		public override Container ProductTagContainer => this._productMetaContainer;
		public override Container SalesOrderContainer => this._customerContainer;
		public override Container SalesOrderDetailContainer => this._customerContainer;

		protected override (string ContainerName, string PartitionKey)[] Containers => new[]
		{
			("customer", "/customerId"),
			("product", "/categoryId"),
			("productMeta", "/type"),
		};

		#endregion

		#region "Initialize"

		protected override async Task OnContainerCreated(string containerName)
		{
			await base.OnContainerCreated(containerName);

			if (containerName != "customer")
			{
				return;
			}

			var container = Shared.Client.GetContainer(this.DatabaseName, containerName);
			var sprocBody = File.ReadAllText(@"spCreateSalesOrder.js");
			var sprocProperties = new StoredProcedureProperties
			{
				Id = "spCreateSalesOrder",
				Body = sprocBody,
			};
			await container.Scripts.CreateStoredProcedureAsync(sprocProperties);
		}

		#endregion

		#region "Generate"

		protected override void GetContainers()
		{
			if (this._customerContainer == null)
			{
				this._customerContainer = base._database.GetContainer("customer");
				this._productContainer = base._database.GetContainer("product");
				this._productMetaContainer = base._database.GetContainer("productMeta");
			}
		}

		protected override async Task CreateCustomerDocuments(int lineIndex)
		{
			var ctr = 0;
			var elapsed = await base.TimeActionAsync(async () =>
			{
				var docs = new List<dynamic>();
				foreach (DataRow row in base._customerTable.Rows)
				{
					this.WriteLine($"({++ctr}) Creating customer", lineIndex + 2);
					var customerId = row["CustomerId"].ToString();
					var addressDocs = base.GenerateCustomerAddressDocuments(customerId);
					var passwordDoc = base.GenerateCustomerPasswordDocument(customerId);
					var orderCount = base._salesOrderTable.AsEnumerable().Count(r => r["CustomerId"].ToString() == customerId);
					dynamic doc = new
					{
						id = customerId,
						type = "customer",
						customerId,
						title = row["Title"].ToString(),
						firstName = row["FirstName"].ToString(),
						lastName = row["LastName"].ToString(),
						emailAddress = row["EmailAddress"].ToString(),
						phoneNumber = row["PhoneNumber"].ToString(),
                        creationDate = Convert.ToDateTime(row["CreationDate"]).ToString("s"),
                        addresses = addressDocs,
						password = passwordDoc,
						salesOrderCount = orderCount,
					};
					docs.Add(doc);
				}
				ctr = 0;
				foreach (var d in docs)
				{
					this.WriteLine($"({++ctr}) Writing customer {d.id}", lineIndex + 2);
					await this.CustomerContainer.CreateItemAsync(d, new PartitionKey(d.id));
				}
			});
			this.WriteLine($"Generated {ctr} customer documents in {elapsed}", lineIndex + 2);
		}

		protected override async Task CreateSalesOrderDocuments(int lineIndex)
		{
			var ctr = 0;
			var elapsed = await base.TimeActionAsync(async () =>
			{
				var docs = new List<dynamic>();
				foreach (DataRow row in base._salesOrderTable.Rows)
				{
					this.WriteLine($"({++ctr}) Creating sales order", lineIndex + 2);
					var salesOrderId = row["SalesOrderId"].ToString();
					var detailDocs = base.GenerateSalesOrderDetailDocuments(salesOrderId);
					dynamic doc = new
					{
						id = salesOrderId,
						type = "salesOrder",
						customerId = row["CustomerId"].ToString(),
                        orderDate = Convert.ToDateTime(row["OrderDate"]).ToString("s"),
                        shipDate = Convert.ToDateTime(row["ShipDate"]).ToString("s"),
                        details = detailDocs,
					};
					docs.Add(doc);
				}
				ctr = 0;
				foreach (var d in docs)
				{
					this.WriteLine($"({++ctr}) Writing sales order {d.id}", lineIndex + 2);
					await this.SalesOrderContainer.CreateItemAsync(d, new PartitionKey(d.customerId));
				}
			});
			this.WriteLine($"Generated {ctr} sales order documents in {elapsed}", lineIndex + 2);
		}

		#endregion
	}
}
