-- *** Remote master database ***

-- Create a SQL Login in the logical server's master database
CREATE LOGIN RemoteLogin WITH PASSWORD='Rem0teP@$$w0rd!'


-- *** Remote AdventureWorks database ***

-- Create a read-only SQL User in the remote database
CREATE USER RemoteUser FOR LOGIN RemoteLogin
EXEC sp_addrolemember 'db_datareader', 'RemoteUser'
GO


-- *** Local master database ***
CREATE DATABASE WebStore (EDITION = 'Basic')
GO


-- *** Local WebStore database***

-- Create a Master Key
PRINT 'Creating external data source'
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD='H@rd2Gue$$P@$$w0rd!'
GO

-- Create a Database Scoped Credential
CREATE DATABASE SCOPED CREDENTIAL RemoteCredential WITH IDENTITY='RemoteLogin', SECRET='Rem0teP@$$w0rd!'

-- Create the external data source
CREATE EXTERNAL DATA SOURCE AW2017Remote
WITH (
	TYPE=RDBMS,
	LOCATION='lennidemo.database.windows.net',
	DATABASE_NAME='AdventureWorks2017',
	CREDENTIAL= RemoteCredential
)

GO

-- Create external tables
PRINT 'Creating external tables'
GO
CREATE SCHEMA Sales
GO
CREATE SCHEMA Person
GO
CREATE SCHEMA Production
GO

CREATE EXTERNAL TABLE Sales.Customer(
	CustomerId int NOT NULL,
	PersonId int NULL)
	WITH (DATA_SOURCE=AW2017Remote)

CREATE EXTERNAL TABLE Person.Person(
	BusinessEntityID int NOT NULL,
	Title nvarchar(8) NULL,
	FirstName nvarchar(50) NOT NULL,
	LastName nvarchar(50) NOT NULL,
	ModifiedDate datetime NOT NULL)
	WITH (DATA_SOURCE=AW2017Remote)

CREATE EXTERNAL TABLE Person.EmailAddress(
	BusinessEntityID int NOT NULL,
	EmailAddress nvarchar(50) NULL)
	WITH (DATA_SOURCE=AW2017Remote)

CREATE EXTERNAL TABLE Person.PersonPhone(
	BusinessEntityID int NOT NULL,
	PhoneNumber nvarchar(25) NULL)
	WITH (DATA_SOURCE=AW2017Remote)

CREATE EXTERNAL TABLE Person.BusinessEntityAddress(
	BusinessEntityID int,
	AddressID int)
	WITH (DATA_SOURCE=AW2017Remote)

CREATE EXTERNAL TABLE Person.Address(
	AddressID int NOT NULL,
	AddressLine1 nvarchar(60) NULL,
	AddressLine2 nvarchar(60) NULL,
	City nvarchar(30) NULL,
	StateProvinceID int NULL,
	PostalCode nvarchar(15) NULL)
	WITH (DATA_SOURCE=AW2017Remote)

CREATE EXTERNAL TABLE Person.StateProvince(
	StateProvinceID int NOT NULL,
	StateProvinceCode nchar(3) NULL,
	CountryRegionCode nvarchar(3) NULL)
	WITH (DATA_SOURCE=AW2017Remote)

CREATE EXTERNAL TABLE Production.ProductSubcategory(
	ProductSubcategoryID int NOT NULL,
	ProductCategoryID int NULL,
	Name nvarchar(50) NULL)
	WITH (DATA_SOURCE=AW2017Remote)

CREATE EXTERNAL TABLE Production.ProductCategory(
	ProductCategoryID int NOT NULL,
	Name nvarchar(50) NULL)
	WITH (DATA_SOURCE=AW2017Remote)

CREATE EXTERNAL TABLE Production.Product(
	ProductID int NOT NULL,
	ProductSubcategoryID int NULL,
	ProductNumber nvarchar(25) NULL,
	Name nvarchar(50) NULL,
	ListPrice money NULL)
	WITH (DATA_SOURCE=AW2017Remote)

CREATE EXTERNAL TABLE Sales.SalesOrderHeader(
	SalesOrderID int NOT NULL,
	CustomerID int NULL,
	OrderDate datetime NULL,
	ShipDate datetime NULL)
	WITH (DATA_SOURCE=AW2017Remote)

CREATE EXTERNAL TABLE Sales.SalesOrderDetail(
	SalesOrderDetailID int NOT NULL,
	SalesOrderID int NOT NULL,
	UnitPrice money,
	OrderQty smallint,
	ProductID int)
	WITH (DATA_SOURCE=AW2017Remote)

GO

SET NOCOUNT ON
GO


-- *** Create tables ***

PRINT 'Creating tables'
GO

CREATE TABLE Customer(
	CustomerId varchar(50) NOT NULL,
	Title nvarchar(8),
	FirstName nvarchar(50) NOT NULL,
	LastName nvarchar(50) NOT NULL,
	EmailAddress nvarchar(50),
	PhoneNumber nvarchar(25),
	CreationDate datetime,
	CONSTRAINT PK_Customer PRIMARY KEY CLUSTERED (CustomerId),
)

CREATE TABLE CustomerAddress(
	CustomerAddressId varchar(50) NOT NULL,
	CustomerId varchar(50) NOT NULL,
	AddressLine1 nvarchar(60) NOT NULL,
	AddressLine2 nvarchar(60),
	City nvarchar(30) NOT NULL,
	State nchar(3) NOT NULL,
	Country nvarchar(3) NOT NULL,
	ZipCode nvarchar(15) NOT NULL,
	CONSTRAINT PK_CustomerAddress PRIMARY KEY CLUSTERED (CustomerAddressId),
	CONSTRAINT FK_CustomerAddress_Customer FOREIGN KEY(CustomerId) REFERENCES Customer (CustomerId) ON UPDATE CASCADE,
)

CREATE TABLE CustomerPassword(
	CustomerId varchar(50) NOT NULL,
	Hash varbinary(8000) NOT NULL,
	Salt varchar(9) NOT NULL,
	CONSTRAINT PK_CustomerPassword PRIMARY KEY CLUSTERED (CustomerId),
	CONSTRAINT FK_CustomerPassword_Customer FOREIGN KEY(CustomerId) REFERENCES Customer (CustomerId) ON UPDATE CASCADE,
)

CREATE TABLE ProductCategory(
	ProductCategoryId varchar(50) NOT NULL,
	Name nvarchar(100) NOT NULL,
	CONSTRAINT PK_ProductCategory PRIMARY KEY CLUSTERED (ProductCategoryId),
)

CREATE TABLE Product(
	ProductId varchar(50) NOT NULL,
	ProductCategoryId varchar(50) NOT NULL,
	Sku nvarchar(25) NOT NULL,
	Name nvarchar(50) NOT NULL,
	Description nvarchar(100) NOT NULL,
	Price money NOT NULL,
	CONSTRAINT PK_Product PRIMARY KEY CLUSTERED (ProductId),
	CONSTRAINT FK_Product_ProductCategory FOREIGN KEY(ProductCategoryId) REFERENCES ProductCategory (ProductCategoryId) ON UPDATE CASCADE,
)

CREATE TABLE ProductTag(
	ProductTagId varchar(50) NOT NULL,
	Name varchar(25) NOT NULL,
	CONSTRAINT PK_ProductTag PRIMARY KEY CLUSTERED (ProductTagId),
)

CREATE TABLE ProductTags(
	ProductId varchar(50) NOT NULL,
	ProductTagId varchar(50) NOT NULL,
	CONSTRAINT PK_ProductTags PRIMARY KEY CLUSTERED (ProductId, ProductTagId),
	CONSTRAINT FK_ProductTags_Product FOREIGN KEY(ProductId) REFERENCES Product (ProductId) ON UPDATE CASCADE,
	CONSTRAINT FK_ProductTags_ProductTag FOREIGN KEY(ProductTagId) REFERENCES ProductTag (ProductTagId) ON UPDATE CASCADE,
)

CREATE TABLE SalesOrder(
	SalesOrderId varchar(50) NOT NULL,
	CustomerId varchar(50) NOT NULL,
	OrderDate datetime NOT NULL,
	ShipDate datetime NULL,
	CONSTRAINT PK_SalesOrder PRIMARY KEY CLUSTERED (SalesOrderId),
	CONSTRAINT FK_SalesOrder_Customer FOREIGN KEY(CustomerId) REFERENCES Customer (CustomerId) ON UPDATE CASCADE,
)

CREATE TABLE SalesOrderDetail(
	SalesOrderDetailId varchar(50) NOT NULL,
	SalesOrderId varchar(50) NOT NULL,
	Sku nvarchar(25) NOT NULL,
	Name nvarchar(50) NOT NULL,
	Price money NOT NULL,
	Quantity smallint NOT NULL,
	CONSTRAINT PK_SalesOrderDetail PRIMARY KEY CLUSTERED (SalesOrderDetailId),
	CONSTRAINT FK_SalesOrderDetail_SalesOrder FOREIGN KEY(SalesOrderId) REFERENCES SalesOrder (SalesOrderId) ON UPDATE CASCADE,
)


-- *** Customer ***

PRINT 'Populating Customer table'
GO

INSERT INTO Customer
SELECT
	c.CustomerId			AS CustomerId,
	p.Title					AS Title,
	p.FirstName				AS FirstName,
	p.LastName				AS LastName,
	e.EmailAddress			AS EmailAddress,
	pp.PhoneNumber			AS PhoneNumber,
	p.ModifiedDate			AS CreationDate
FROM
	Sales.Customer AS c
	INNER JOIN Person.Person AS p ON p.BusinessEntityId = c.PersonId
	LEFT JOIN Person.EmailAddress AS e ON e.BusinessEntityId = c.PersonId
	LEFT JOIN Person.PersonPhone AS pp ON pp.BusinessEntityId = c.PersonId


-- *** CustomerAddress ***

PRINT 'Populating CustomerAddress table'
GO

INSERT INTO CustomerAddress
SELECT
	a.AddressId			AS CustomerAddressId,
	c.CustomerId		AS CustomerId,
	a.AddressLine1		AS AddressLine1,
	a.AddressLine2		AS AddressLine2,
	a.City				AS City,
	s.StateProvinceCode	AS State,
	s.CountryRegionCode	AS Country,
	a.PostalCode		AS ZipCode
FROM
	Person.BusinessEntityAddress AS bea
	INNER JOIN Person.Address AS a ON a.AddressId = bea.AddressId
	INNER JOIN Sales.Customer AS c ON c.PersonId = bea.BusinessEntityId
	INNER JOIN Person.StateProvince AS s ON s.StateProvinceId = a.StateProvinceId


-- *** CustomerPassword ***

PRINT 'Populating CustomerPassword table'
GO

INSERT INTO CustomerPassword
SELECT
	CustomerId										AS CustomerId,
	HASHBYTES('SHA2_256', emailAddress)				AS Hash,
	SUBSTRING(CONVERT(varchar(40), NEWID()), 0, 9)	AS Salt
FROM
	Customer


-- *** ProductCategory ***

PRINT 'Populating ProductCategory table'
GO

INSERT INTO ProductCategory
SELECT
	sc.ProductSubcategoryId			AS ProductCategoryId,
	CONCAT(c.Name, ', ', sc.Name)	AS Name
FROM
	Production.ProductSubcategory AS sc
	INNER JOIN Production.ProductCategory AS c ON c.ProductCategoryID = sc.ProductCategoryID


-- *** Product ***

PRINT 'Populating Product table'
GO

INSERT INTO Product
SELECT
	ProductId									AS ProductId,
	ProductSubcategoryID						AS ProductCategoryId,
	ProductNumber								AS Sku,
	Name										AS Name,
	CONCAT('The product called "', Name, '"')	AS Description,
	ListPrice									AS Price
FROM
	Production.Product
WHERE
	ProductSubcategoryId IS NOT NULL


-- *** ProductTag ***

PRINT 'Populating ProductTag table'
GO

WITH RowGenerationCte (ProductTagId) AS (
	SELECT 1 AS ProductTagId UNION ALL
	SELECT c.ProductTagId + 1 AS ProductTagId FROM RowGenerationCte AS c WHERE c.ProductTagId < 200
)
INSERT INTO ProductTag
	SELECT ProductTagId, CONCAT('Tag-', ProductTagId) AS Name
	FROM RowGenerationCte
	OPTION (MAXRECURSION 200)


-- *** ProductTags ***

PRINT 'Populating ProductTags table'
GO

DECLARE @ProductId int
DECLARE curTags CURSOR FOR SELECT ProductId FROM Product
OPEN curTags
FETCH NEXT FROM curTags INTO @ProductId
WHILE @@FETCH_STATUS = 0 BEGIN
	DECLARE @TagCount int = FLOOR(RAND() * (5 + 0 + 1)) + 0
	DECLARE @TagIndex int = 0
	WHILE @TagIndex < @TagCount BEGIN
		DECLARE @Retry bit = 1
		WHILE @Retry = 1 BEGIN
			DECLARE @TagId int = FLOOR(RAND() * (200 + 1 + 1)) + 1
			IF (EXISTS(SELECT * FROM ProductTags WHERE ProductId = @ProductId AND ProductTagId = @TagId)) OR (NOT EXISTS(SELECT * FROM ProductTag WHERE ProductTagId = @TagId))
				SET @TagId = FLOOR(RAND() * (200 + 1 + 1)) + 1
			ELSE
				SET @Retry = 0
		END
		INSERT INTO ProductTags VALUES(@ProductId, @TagId)
		SET @TagIndex += 1
	END
	FETCH NEXT FROM curTags INTO @ProductId
END
CLOSE curTags
DEALLOCATE curTags


-- *** SalesOrder ***

PRINT 'Populating SalesOrder table'
GO
INSERT INTO SalesOrder
SELECT
	SalesOrderID		AS SalesOrderId,
	CustomerID			AS CustomerId,
	OrderDate			AS OrderDate,
	ShipDate			AS ShipDate
FROM
	Sales.SalesOrderHeader


-- *** SalesOrderDetail ***

PRINT 'Populating SalesOrderDetail table'
GO
INSERT INTO SalesOrderDetail
SELECT
	sod.SalesOrderDetailID	AS SalesOrderDetailId,
	sod.SalesOrderID		AS SalesOrderId,
	p.ProductNumber			AS Sku,
	p.Name					AS Name,
	sod.UnitPrice			AS Price,
	sod.OrderQty			AS Quantity
FROM
	Sales.SalesOrderDetail AS sod
	INNER JOIN Production.Product AS p ON p.ProductID = sod.ProductID


-- *** Convert primary key string integers into string GUIDs ***

PRINT 'Converting Customer PK to GUIDs'
GO
UPDATE Customer SET CustomerID = CONVERT(varchar(50), NEWID())
UPDATE Customer SET CustomerID = '46192BCF-E8BB-4140-A0F1-B8764A7941E7' WHERE FirstName = 'Amanda' AND LastName = 'Cook' -- was customer id 11279
UPDATE Customer SET CustomerID = '44A6D5F6-AF44-4B34-8AB5-21C5DC50926E' WHERE FirstName = 'Dalton' AND LastName = 'Perez' -- was customer id 11091

PRINT 'Converting CustomerAddress PK to GUIDs'
GO
UPDATE CustomerAddress SET CustomerAddressID = CONVERT(varchar(50), NEWID())

PRINT 'Converting Product PK to GUIDs'
GO
UPDATE Product SET ProductId = CONVERT(varchar(50), NEWID())
UPDATE Product SET ProductId = 'F59ECC09-CAA5-4D3C-87A7-16945A92EA2D' WHERE Name = 'Women''s Mountain Shorts, S'			-- was product id 867

PRINT 'Converting ProductCategory PK to GUIDs'
GO
UPDATE ProductCategory SET ProductCategoryId = CONVERT(varchar(50), NEWID())
UPDATE ProductCategory SET ProductCategoryId = 'C7324EF3-D951-45D9-A345-A82EAE344394' WHERE Name = 'Clothing, Shorts'  -- was product category id 22

PRINT 'Converting ProductTag PK to GUIDs'
GO
UPDATE ProductTag SET ProductTagID = CONVERT(varchar(50), NEWID())

PRINT 'Converting SalesOrder PK to GUIDs'
GO
UPDATE SalesOrder SET SalesOrderID = CONVERT(varchar(50), NEWID())

PRINT 'Converting SalesOrderDetail PK to GUIDs'
GO
UPDATE SalesOrderDetail SET SalesOrderDetailID = CONVERT(varchar(50), NEWID())


-- *** Drop external references ***

PRINT 'Dropping external tables'
GO

DROP EXTERNAL TABLE Sales.Customer
DROP EXTERNAL TABLE Person.Person
DROP EXTERNAL TABLE Person.EmailAddress
DROP EXTERNAL TABLE Person.PersonPhone
DROP EXTERNAL TABLE Person.BusinessEntityAddress
DROP EXTERNAL TABLE Person.Address
DROP EXTERNAL TABLE Person.StateProvince
DROP EXTERNAL TABLE Production.ProductSubcategory
DROP EXTERNAL TABLE Production.ProductCategory
DROP EXTERNAL TABLE Production.Product
DROP EXTERNAL TABLE Sales.SalesOrderHeader
DROP EXTERNAL TABLE Sales.SalesOrderDetail
DROP SCHEMA Sales
DROP SCHEMA Person
DROP SCHEMA Production

PRINT 'Dropping external data source'
GO

DROP EXTERNAL DATA SOURCE AW2017Remote
DROP DATABASE SCOPED CREDENTIAL RemoteCredential
DROP MASTER KEY
GO

PRINT 'Done'
GO



-- *** Examine final WebStore database ***

/*
-- Customers with > 1 address and > 1 order
;WITH AddressCountsCte AS (
	SELECT c.CustomerId, c.FirstName, c.LastName, COUNT(*) AS AddressCount
	FROM Customer AS c INNER JOIN CustomerAddress AS ca ON ca.CustomerId = c.CustomerId
	GROUP BY c.CustomerId, c.FirstName, c.LastName),
OrderCountsCte AS (
	SELECT c.CustomerId, c.FirstName, c.LastName, COUNT(*) AS SalesOrderCount
	FROM Customer AS c INNER JOIN SalesOrder AS so ON so.CustomerId = c.CustomerId
	GROUP BY c.CustomerId, c.FirstName, c.LastName)
SELECT
	o.CustomerId,
	o.FirstName,
	o.LastName,
	a.AddressCount,
	o.SalesOrderCount
FROM
	AddressCountsCte AS a
	INNER JOIN OrderCountsCte AS o ON o.CustomerId = a.CustomerId
WHERE
	AddressCount > 1 AND SalesOrderCount > 1
ORDER BY
	o.LastName

-- Product categories and products
SELECT pc.ProductCategoryId, pc.Name, ProductCount = (SELECT COUNT(*) FROM Product WHERE ProductCategoryId = pc.ProductCategoryId), p.ProductId, p.Name
FROM ProductCategory AS pc INNER JOIN Product AS p ON p.ProductCategoryId = pc.ProductCategoryId
ORDER BY pc.Name, p.Name


SELECT
	Customer			= (SELECT COUNT(*) FROM Customer),
	CustomerAddress		= (SELECT COUNT(*) FROM CustomerAddress),
	CustomerPassword	= (SELECT COUNT(*) FROM CustomerPassword),
	ProductCategory		= (SELECT COUNT(*) FROM ProductCategory),
	Product				= (SELECT COUNT(*) FROM Product),
	ProductTag			= (SELECT COUNT(*) FROM ProductTag),
	ProductTags			= (SELECT COUNT(*) FROM ProductTags),
	SalesOrder			= (SELECT COUNT(*) FROM SalesOrder),
	SalesOrderDetail	= (SELECT COUNT(*) FROM SalesOrderDetail)

SELECT TOP 100 * FROM Customer
SELECT TOP 100 * FROM CustomerAddress
SELECT TOP 100 * FROM CustomerPassword
SELECT TOP 100 * FROM ProductCategory
SELECT TOP 100 * FROM Product
SELECT TOP 100 * FROM ProductTag
SELECT TOP 100 * FROM ProductTags
SELECT TOP 100 * FROM SalesOrder
SELECT TOP 100 * FROM SalesOrderDetail
*/

-- Cleanup

ALTER TABLE CustomerAddress DROP CONSTRAINT FK_CustomerAddress_Customer
ALTER TABLE CustomerPassword DROP CONSTRAINT FK_CustomerPassword_Customer
ALTER TABLE Product DROP CONSTRAINT FK_Product_ProductCategory
ALTER TABLE ProductTags DROP CONSTRAINT FK_ProductTags_Product
ALTER TABLE ProductTags DROP CONSTRAINT FK_ProductTags_ProductTag
ALTER TABLE SalesOrder DROP CONSTRAINT FK_SalesOrder_Customer
ALTER TABLE SalesOrderDetail DROP CONSTRAINT FK_SalesOrderDetail_SalesOrder

DROP TABLE IF EXISTS Customer
DROP TABLE IF EXISTS CustomerAddress
DROP TABLE IF EXISTS CustomerPassword
DROP TABLE IF EXISTS ProductCategory
DROP TABLE IF EXISTS Product
DROP TABLE IF EXISTS ProductTag
DROP TABLE IF EXISTS ProductTags
DROP TABLE IF EXISTS SalesOrder
DROP TABLE IF EXISTS SalesOrderDetail
