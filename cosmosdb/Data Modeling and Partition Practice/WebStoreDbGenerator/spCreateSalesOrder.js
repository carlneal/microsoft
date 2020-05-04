function spCreateSalesOrder(salesOrderDoc) {

	if (!salesOrderDoc) {
		throw new Error("Parameter 'salesOrderDoc' is null or undefined.");
	}

	var context = getContext();
	var collection = context.getCollection();
	var collectionLink = collection.getSelfLink();
	var customerDocLink = collection.getAltLink() + "/docs/" + salesOrderDoc.customerId;
	var response = context.getResponse();

	// Retrieve customer document	
	collection.readDocument(customerDocLink, function (err, customerDoc) {
		if (err) throw err;
		// Increment sales order count in customer document and replace it in the container
		customerDoc.salesOrderCount++;
		collection.replaceDocument(customerDoc._self, customerDoc, function (err) {
			if (err) throw err;
			// Create the sales order document
			collection.createDocument(collectionLink, salesOrderDoc, function (err, doc) {
				if (err) throw err;
				response.setBody(customerDoc.salesOrderCount);
			});
		});
	});
}
