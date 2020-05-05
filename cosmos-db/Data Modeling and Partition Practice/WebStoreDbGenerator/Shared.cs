using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;

namespace WebStoreDbGenerator
{
	public static class Shared
	{
		public static CosmosClient Client { get; private set; }
		public static string WebStoreDbConnStr { get; private set; }

		static Shared()
		{
			var config = new ConfigurationBuilder().AddJsonFile("appsettings.json").Build();
			var endpoint = config["CosmosEndpoint"];
			var masterKey = config["CosmosMasterKey"];
			var sqlConnStr = config["WebStoreDb"];

			Client = new CosmosClient(endpoint, masterKey);
			WebStoreDbConnStr = sqlConnStr;
		}

	}
}
