using System;
using System.Threading.Tasks;

namespace WebStoreDbGenerator
{
	public static class Program
	{
		public static void Main(string[] args)
		{
			Console.WriteLine("Cosmos DB WebStore eCommerce Database Generator");
			Console.WriteLine();

			if (args.Length > 0)
			{
				RunOperation(args).Wait();
			}
			else
			{
				RunInteractive().Wait();
			}
		}

		private static async Task RunInteractive()
		{
			ShowUsage();
			while (true)
			{
				Console.Write("WebStore> ");
				var input = Console.ReadLine();
				if (!string.IsNullOrWhiteSpace(input))
				{
					if ("quit".StartsWith(input.ToLower()))
					{
						break;
					}
					var args = input.Split(' ');
					await RunOperation(args);
				}
			}
		}

		private static (WebStoreRepoBase, string) GetRepoAndOperation(string[] args)
		{
			var operation = args[0].ToLower();
			var arg1 = args.Length > 1 ? args[1].ToUpper() : null;
			var repo = default(WebStoreRepoBase);
			if (Enum.TryParse(arg1, out VersionIdentifier version))
			{
				repo = WebStoreRepoFactory.GetRepo(version);
			}
			return (repo, operation);
		}

		private static async Task RunOperation(string[] args)
		{
			try
			{
				var (repo, operation) = GetRepoAndOperation(args);
				if (operation.Matches("initialize"))
				{
					await repo.InitializeDatabase();
				}
				else if (operation.Matches("delete"))
				{
					await repo.DeleteDatabase(confirm: true);
				}
				else if (operation.Matches("generate"))
				{
					repo.GenerateData();
				}
				else if (operation.Matches("ccn"))
				{
					await repo.ChangeProductCategoryName();
				}
				else if (operation.Matches("ctn"))
				{
					await repo.ChangeProductTagName();
				}
				else if (operation.Matches("cso"))
				{
					await repo.CreateSalesOrder();
				}
				else if (operation.Matches("help") || operation == "?")
				{
					ShowUsage();
				}
				else
				{
					throw new Exception("Unrecognized command");
				}
			}
			catch (Exception ex)
			{
				Console.WriteLine($"Error: {ex.Message}");
				ShowUsage();
			}
		}

		private static bool Matches(this string operation, string match) =>
			match.StartsWith(operation);

		private static void ShowUsage()
		{
			Console.WriteLine("Usage:");
			Console.WriteLine("  initialize v[n]  initialize database for demo version [n] (1-4)");
			Console.WriteLine("  delete v[n]      delete database");
			Console.WriteLine("  generate v[n]    generate data");
			Console.WriteLine("  ccn v[n]         change category name (change feed)");
			Console.WriteLine("  ctn v[n]         change tag name (change feed)");
			Console.WriteLine("  cso v[n]         create sales order (stored procedure)");
			Console.WriteLine("  help (or ?)      show usage");
			Console.WriteLine("  quit             exit utility");
			Console.WriteLine();
		}

	}
}
