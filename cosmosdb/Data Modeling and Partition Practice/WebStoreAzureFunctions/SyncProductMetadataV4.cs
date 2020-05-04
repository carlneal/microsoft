using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Documents;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace WebStoreAzureFunctions
{
	public static class SyncProductMetadataV4
	{
		private static CosmosClient Client { get; set; }

		private const string ConnectionStringSetting = "CosmosDbConnectionString";
		private const string DatabaseId = "webstore-v4";
		private const string ProductMetaContainerId = "productMeta";
		private const string LeaseContainerId = "lease";

		static SyncProductMetadataV4()
		{
			var connStr = Environment.GetEnvironmentVariable(ConnectionStringSetting);
			Client = new CosmosClient(connStr);
		}

		[FunctionName("SyncProductMetadata")]
		public static async Task SyncProductMetadata(
			[CosmosDBTrigger(
				databaseName: DatabaseId,
				collectionName: ProductMetaContainerId,
				ConnectionStringSetting = ConnectionStringSetting,
				LeaseCollectionName = LeaseContainerId,
				CreateLeaseCollectionIfNotExists = true
			)]
			IReadOnlyList<Document> documents,
			ILogger log)
		{
			log.LogInformation($"Change detected in {documents.Count} product metadata document(s)");
			foreach (var document in documents)
			{
				var item = JsonConvert.DeserializeObject<dynamic>(document.ToString());
				string type = item.type;

				switch (type)
				{
					case "category":
						string categoryId = item.id;
						string categoryName = item.name;
						await UpdateProductCategoryName(log, categoryId, categoryName);
						break;

					case "tag":
						string tagId = item.id;
						string tagName = item.name;
						await UpdateProductTagName(log, tagId, tagName);
						break;
				}
			}
		}

		private static async Task UpdateProductCategoryName(ILogger log, string categoryId, string categoryName)
		{
			var sql = $"SELECT * FROM c WHERE c.categoryId = '{categoryId}'";
			var productContainer = Client.GetContainer(DatabaseId, "product");
			var options = new QueryRequestOptions { PartitionKey = new Microsoft.Azure.Cosmos.PartitionKey(categoryId) };
			var iterator = productContainer.GetItemQueryIterator<dynamic>(sql, requestOptions: options);
			var ctr = 0;
			while (iterator.HasMoreResults)
			{
				var page = await iterator.ReadNextAsync();
				foreach (var productDocument in page)
				{
					log.LogInformation($" Updating product ID {productDocument.id} with new category name '{categoryName}'");
					productDocument.categoryName = categoryName;
					await productContainer.ReplaceItemAsync(productDocument, productDocument.id.ToString());
					ctr++;
				}
			}

			log.LogInformation($"Propagated new category name '{categoryName}' (id '{categoryId}') to {ctr} product document(s)");
		}

		private static async Task UpdateProductTagName(ILogger log, string tagId, string tagName)
		{
			var sql = $"SELECT * FROM c WHERE ARRAY_CONTAINS(c.tags, {{'id': '{tagId}'}}, true)";
			var productContainer = Client.GetContainer(DatabaseId, "product");
			var options = new QueryRequestOptions { MaxConcurrency = -1  };
			var iterator = productContainer.GetItemQueryIterator<dynamic>(sql, requestOptions: options);
			var ctr = 0;
			while (iterator.HasMoreResults)
			{
				var page = await iterator.ReadNextAsync();
				foreach (var productDocument in page)
				{
					log.LogInformation($" Updating product ID {productDocument.id} with new tag name '{tagName}'");
					var tag = ((IEnumerable<dynamic>)productDocument.tags).First(t => t.id == tagId);
					tag.name = tagName;
					await productContainer.ReplaceItemAsync(productDocument, productDocument.id.ToString());
					ctr++;
				}
			}

			log.LogInformation($"Propagated new tag name '{tagName}' (id '{tagId}') to {ctr} product document(s)");
		}

	}
}
