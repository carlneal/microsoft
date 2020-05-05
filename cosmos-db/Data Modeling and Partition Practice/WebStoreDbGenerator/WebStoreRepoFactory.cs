using System;

namespace WebStoreDbGenerator
{
	public static class WebStoreRepoFactory
	{
		public static WebStoreRepoBase GetRepo(VersionIdentifier version)
		{
			var typeName = $"WebStoreDbGenerator.{version}.WebStore{version}Repo";
			try
			{
				var type = Type.GetType(typeName);
				var obj = Activator.CreateInstance(type);
				return (WebStoreRepoBase)obj;
			}
			catch
			{
				throw new Exception($"Can't create instance of {typeName} for version {version}");
			}
		}

	}
}
