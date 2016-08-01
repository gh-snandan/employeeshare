@isTest
private class OpportunityTriggerTest {
	static User newSalesRep;
	static User newSalesManager;
	static List<Lead> leadList;
	static List<Lead> convertedLead;
	static List<Opportunity> oppu;
	static List<OpportunityLineItem> itemsu;
	static List<Inventory__c> invnfromoppu;
	static List<OpportunityLineItem> items;
	static List<Opportunity> opp;
	static List<Inventory__c> invnfromopp;
	


	//another line added
	/*
	* create sales user
	*/
	@isTest
	static void prepareSalesRepData(){
		// get the Sales Rep profile for user creation
		List<Profile> salesRepProfile = [ Select Id, Name from Profile where Name ='SalesRep' limit 1 ];
		System.assertNotEquals( null, salesRepProfile[0].Id );
		//System.assert( (salesRepProfile[0].Id != null), 'Fails for checking profile' );
		
		// create the test Sales Rep user 
		newSalesRep = new User();
		newSalesRep.UserName = 'tsalesrep@abc.com';
		newSalesRep.Email = 'tsalesrep@abc.com';
		newSalesRep.LastName = 'TestSalesRep';
		newSalesRep.Alias = 'tsalerep';
		newSalesRep.IsActive = true;
		newSalesRep.ProfileId = salesRepProfile[0].Id;
		newSalesRep.LanguageLocaleKey = 'en_US';
		newSalesRep.EmailEncodingKey = 'UTF-8';
		newSalesRep.TimeZoneSidKey = 'America/Los_Angeles';
		newSalesRep.LocaleSidKey = 'en_US';
		try{
			insert newSalesRep;
		}catch( Exception ex ){
			System.assert( false, 'Fails for user creation. Details: ' + ex.getMessage() );
		}
	}
	
	/*
	* create sales manager
	*/
	@isTest
	static void prepareSalesManagerData(){
		// get the Sales Rep profile for user creation
		List<Profile> salesManagerProfile = [ Select Id, Name from Profile where Name ='SalesManager' limit 1 ];
		System.assertNotEquals( null, salesManagerProfile[0].Id );
		
		// create the test Sales Manager user
		newSalesManager = new User();
		newSalesManager.UserName = 'tsalesM@abc.com';
		newSalesManager.Email = 'tsalesM@abc.com';
		newSalesManager.LastName = 'tsalesM';
		newSalesManager.Alias = 'tsalesM';
		newSalesManager.IsActive = true;
		newSalesManager.ProfileId = salesManagerProfile[0].Id;
		newSalesManager.LanguageLocaleKey = 'en_US';
		newSalesManager.EmailEncodingKey = 'UTF-8';
		newSalesManager.TimeZoneSidKey = 'America/Los_Angeles';
		newSalesManager.LocaleSidKey = 'en_US';
		try{
			insert newSalesManager;
		}catch( Exception ex ){
			System.assert( false, 'Fails for user creation. Details: ' + ex.getMessage() );
		}
	}
	
	
	/*
	* create new lead
	* convert lead to account, contact and opportunity
	*/
	@isTest(SeeAllData=true)
	static void testLeadCreation(){
		// create lead
			Lead newLead = new Lead();
			newLead.LastName = 'tlLastname';
			newLead.Email = 'testlead@acmet.com';
			newLead.Company = 'LeadCom';
			newLead.Status = 'Open - Not Contacted';
			
			//insert lead
			try{
				insert newLead;
			}catch( Exception ex ){
				//if we not write anthing inside catch block progrm will run from next line though dml have an exception
				//system.assert(false) - to stop the progrm for exception forcefully.
				System.assert( false, 'Fails to create Lead. Details : ' + ex.getMessage() );
			}
			
			//query lead which have been inserted
			leadList = [select Id, Email, LastName from Lead where Id =:newLead.Id];
			System.assertNotEquals( null, leadList[0].Id,'Fails to create new lead');
			
			//convert lead into account, contact and opp
			Database.LeadConvert lc = new Database.LeadConvert();
			
			lc.setLeadId(newLead.Id);
			
			List<LeadStatus> convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];		
			lc.setConvertedStatus( convertStatus[0].MasterLabel );
			
			Database.LeadConvertResult lcr;
			 
			try{
				lcr = Database.convertLead(lc);
			}catch( Exception ex ){
				System.assert(false,'fails to convert' + ex.getMessage() );
			}
			
			//query the lead which converted into acc, con and opp
			convertedLead = [select FirstName, LastName, Email, isConverted,
                      					ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId from Lead 
                      					where Id = : newLead.Id ];
			//query the contact created from lead conversion
			List<Contact> con = [select Id, FirstName, LastName from Contact 
            					where Id =: convertedLead[0].ConvertedContactId];
			System.assertNotEquals( null, con[0].Id, 'lead not converted to contact' );
			//query the account created from lead conversion
			List<Account> acc = [select Id, Name from Account where Id =:convertedLead[0].ConvertedAccountId];
			System.assertNotEquals( null, acc[0].Id, 'lead not converted to account' );
			//query the opportunity created from lead conversion
			opp = [select Id, Name, StageName from Opportunity where  
					Id =:convertedLead[0].ConvertedOpportunityId];
			System.assertNotEquals( null, opp[0].Id, 'lead not converted to opportunity' );
	}

	
	/*
	* when opportunity is open move stagename to any thing else(not closed won)
	* inventory will not be created automatically
	*/
	@isTest(SeeAllData=true)
	static void testInventoryNotcreatedOpenOpp(){
		testLeadCreation();
		// case-1: 
        // change the open opp stage to any thing else(dont close the opp)
        // invtory should not be created automatically
        convertedLead = [select FirstName, LastName, Email, isConverted,
                      					ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId from Lead 
                      					where Id = : leadList[0].Id ];
        opp = [select Id, Name, StageName from Opportunity where  
				Id =:convertedLead[0].ConvertedOpportunityId];
		System.assertEquals( 'Initial Contact', opp[0].StageName );
   		opp[0].StageName = 'Needs Analysis';
        try{
        	OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
        	update opp[0];
        }catch( Exception ex){
        	System.assert( false,'stage cannot be updated' + ex.getMessage() );
        }
		opp = [ Select Name, HasOpportunityLineItem, StageName from Opportunity where Id =:opp[0].Id ];
		System.assertEquals( 'Needs Analysis', opp[0].StageName );
		//check there is no opplineitem
		items = [Select Id from OpportunityLineItem where OpportunityId IN :opp];
		System.assertEquals( true, items.isEmpty(), 'oppli is there' );
		//check there is no inventory
		invnfromopp = [Select Id from Inventory__c where OpportunityN__c IN :opp];
		System.assertEquals( true, invnfromopp.isEmpty(), 'inventory is there' );
	}
	
	/*
	* create oppline item, inventory from opportunity with future close date
	* case 1 - Inventory is a child of opportunity
	* Inventory create, When opportunity stage changed to closed won Inventory will be created
	* for each OppLine Item and quantity and relates with Opportunity.
	*/
	@isTest(SeeAllData=true)
	static void testInventoryCreationFuture(){
		testLeadCreation();
		opp = [select Id, Name, StageName from Opportunity where  
				Id =:convertedLead[0].ConvertedOpportunityId];
		//case-3
        //create product and add this to stadard pricebook
        //create pricebookentry with previous created product
        //add pricebookentry with opp
        //create opplineitem for opp
		//create new product , pricebookentry and opportunity
		List<Product2> productlist = new List<Product2>();
		Product2 newProd = new Product2(Name = 'test product');
		productlist.add(newProd);
		Product2 newProd1 = new Product2(Name = 'test product1');
		productlist.add(newProd1);
		try{
			OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
			insert productlist;
			
		}catch(Exception ex){
			System.assert(false,' product cannot be created' + ex.getMessage());
		}
		
		//insert pricebookentry
		List<PriceBookEntry> pbEntryList = new List<PriceBookEntry>();
		PriceBookEntry pbEntry = new PriceBookEntry();
		pbEntry.UnitPrice = 300;
		pbEntry.PriceBook2Id = [select Id from PriceBook2 where isStandard = true].Id;
		pbEntry.Product2Id = newProd.Id;
		pbEntry.IsActive = true;
		pbEntryList.add(pbEntry);
		
		PriceBookEntry pbEntry1 = new PriceBookEntry();
		pbEntry1.UnitPrice = 400;
		pbEntry1.PriceBook2Id = [select Id from PriceBook2 where isStandard = true].Id;
		pbEntry1.Product2Id = newProd1.Id;
		pbEntry1.IsActive = true;
		pbEntryList.add(pbEntry1);
		try{
			OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
			insert pbEntryList ;
		}catch(Exception ex){
			System.assert(false,' pricebookentry cannot be created' + ex.getMessage());
		}
		
		//create new opportunitylineitem for opp
		OpportunityLineItem oli = new OpportunityLineItem();
		Oli.PricebookEntryId = pbEntry.Id;
		Oli.Quantity = 3;
		Oli.OpportunityId = opp[0].Id;
		Oli.TotalPrice = 1000;
		
		OpportunityLineItem oli1 = new OpportunityLineItem();
		Oli1.PricebookEntryId = pbEntry1.Id;
		Oli1.Quantity = 3;
		Oli1.OpportunityId = opp[0].Id;
		Oli1.TotalPrice = 2000;
	
		items = new List<OpportunityLineItem>();
		items.add(oli);
		items.add(oli1);
		try{
	    	OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
	    	insert items;
	    }catch(Exception ex){
	    	System.assert(false, 'opportunitylineitem cannot be inserted' + ex.getMessage());
	    }
	    
	    //check opportunitylineitem has been inserted
		items = [Select Name from OpportunityLineItem where OpportunityId =:opp[0].Id AND Id =: items[0].Id ];
		System.assertEquals(true, items[0].Name.contains( 'test product' ));
	    
	    //case-4
	    //change the stage of opportunity to closed won
	    //check inventory created for each opplineitem
		opp = [ Select StageName from Opportunity where Id =:opp[0].Id ];
		opp[0].StageName = 'Closed Won';
		try{	
			OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
			update opp;
		}catch( Exception ex){
			System.assert( false, 'opportunity stage cannot be moved to closed won' + ex.getMessage());
		}
        //check opportunity stage name chnged to closed won
		opp = [ Select StageName from Opportunity where Id =:opp[0].Id ];
		System.assertEquals('Closed Won', opp[0].StageName );
		items = [Select Name, Quantity from OpportunityLineItem where OpportunityId =:opp[0].Id AND Id =: items[0].Id ];
	    //check inventory created from
	    //check number of invntry is 3(as there is oppli with quantity 3)
		invnfromopp = [Select Id,OppLineItemId__c from Inventory__c where OpportunityN__c IN :opp AND OppLineItemId__c =:items[0].Id];
		System.assertEquals( items[0].Id, invnfromopp[0].OppLineItemId__c, 'inventory not equals with oppline item' );
		System.assertEquals( items[0].Quantity, invnfromopp.size(), 'inventory list not equal with the quantity of opplineitem '  );
		System.assertEquals( true, !invnfromopp.isEmpty(), 'inventory is not there' );
		System.assertEquals( 3, invnfromopp.size(), 'number of inventory is not equal with the number of opplineitem' );
		
		invnfromopp = [Select Id,OppLineItemId__c from Inventory__c where OpportunityN__c IN :opp ];
		System.assertEquals( 6, invnfromopp.size(), 'number of inventory is not equal with the number of opplineitem' );
	}
	
	@isTest(SeeAllData=true)
	static void changeInventorySatusShipped(){
		testLeadCreation();
		testInventoryCreationFuture();
		
		//case-6
        //change one inventory status to shipped.
        //then change the opportunity stage from closed won to anything else,
        //inventory with new status will be deleted and inventory with shipped status will be changed to on hold
        opp = [ Select Name, IsPrivate, StageName from Opportunity where Id =:opp[0].Id ];
		invnfromopp = [Select Status__c from Inventory__c where OpportunityN__c IN :opp ];
		invnfromopp[0].Status__c = 'Shipped';
		invnfromopp[1].Status__c = 'Shipped';
		try{
			OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
        	update invnfromopp;
        }catch(Exception ex){
        	System.assert(false,'status cannot be changed for inventory' + ex.getMessage());
		}
		
		//check inventory status changed to shipped
		invnfromopp = [Select Status__c from Inventory__c where OpportunityN__c IN :opp ];
		

	}
	
	/*
	*create opp with past closed date, 
	*create opplineitem and inventory
	*/
	@isTest(SeeAllData=true)
	static void createOpportunityOppLIInventoryPast(){
		//create product and add this to stadard pricebook
        //create pricebookentry with previous created product
        //add pricebookentry with opp
        //create opplineitem for opp
		Product2 newProdu = new Product2(Name = 'test product u');
		try{
			OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
			insert newProdu;
		}catch(Exception ex){
			System.assert(false,' product cannot be created' + ex.getMessage());
		}
		
		//insert pricebookentry
		PriceBookEntry pbEntryu = new PriceBookEntry();
		pbEntryu.UnitPrice = 300;
		pbEntryu.PriceBook2Id = [select Id from PriceBook2 where isStandard = true].Id;
		pbEntryu.Product2Id = newProdu.Id;
		pbEntryu.IsActive = true;
        
		try{
			OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
			insert pbEntryu ;
		}catch(Exception ex){
			System.assert(false,' pricebookentry cannot be created' + ex.getMessage());
		}
		//insert opportunity
		Opportunity testOppu = new Opportunity();
		testOppu.Name = 'testop';
		testOppu.StageName = 'Initial Contact';
		testOppu.CloseDate = Date.valueOf('2015-03-12');
		
		try{
			insert testOppu;
		}catch(Exception ex){
			System.assert( false,'opportunity cannot be inserted' + ex.getMessage() );
		}
		//check opportunity has been inserted
		oppu = [Select Name from Opportunity where Id =:testOppu.Id];
		System.assertEquals( testOppu.Id, oppu[0].Id, 'Opportunity cannot be created' );
		
		//create new opportunitylineitem for opp
		OpportunityLineItem oliu = new OpportunityLineItem();
		Oliu.PricebookEntryId = pbEntryu.Id;
		Oliu.Quantity = 3;
		Oliu.OpportunityId = oppu[0].Id;
		Oliu.TotalPrice = 1000;
		
		itemsu = new List<OpportunityLineItem>();
		itemsu.add(oliu);
		try{
	    	OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
	    	insert itemsu;
	    }catch(Exception ex){
	    	System.assert(false, 'opportunitylineitem cannot be inserted' + ex.getMessage());
	    }
	    
	    //check opportunitylineitem has been inserted
		itemsu = [Select Name from OpportunityLineItem where OpportunityId =:oppu[0].Id AND Id =: itemsu[0].Id ];
		System.assertEquals(true, itemsu[0].Name.contains( 'test product u' ));
		
		//case-1
	    //change the stage of opportunity to closed won
	    //check inventory created for each opplineitem
		oppu = [ Select StageName from Opportunity where Id =:testOppu.Id];
		oppu[0].StageName = 'Closed Won';
		try{	
			OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
			update oppu;
		}catch( Exception ex){
			System.assert( false, 'opportunity stage cannot be moved to closed won' + ex.getMessage());
		}
        //check opportunity stage name chnged to closed won
		oppu = [ Select StageName, CloseDate from Opportunity where Id =:testOppu.Id];
		System.assertEquals('Closed Won', oppu[0].StageName );
		System.assertEquals( Date.valueOf('2015-03-12'), oppu[0].Closedate);
		itemsu = [Select Name, Quantity from OpportunityLineItem where OpportunityId =:oppu[0].Id AND Id =: itemsu[0].Id ];
	    //check inventory created from
	    //check number of invntry is 3(as there is oppli with quantity 3)
		invnfromoppu = [Select Id,OppLineItemId__c from Inventory__c where OpportunityN__c IN :oppu AND OppLineItemId__c =:itemsu[0].Id];
		System.assertEquals( itemsu[0].Id, invnfromoppu[0].OppLineItemId__c, 'inventory not equals with oppline item' );
		System.assertEquals( itemsu[0].Quantity, invnfromoppu.size(), 'inventory list not equal with the quantity of opplineitem '  );
		
		invnfromoppu = [Select Id,OppLineItemId__c from Inventory__c where OpportunityN__c IN :oppu ];
		System.assertEquals( 3, invnfromoppu.size(), 'number of inventory is not equal with the number of opplineitem' );
	}
	/*
	* Sales Rep
	* test -sales Rep can create lead, converted this to account and opportunity
	*/
	@isTest(SeeAllData=true)
	static void testCreateLeadOpp_SalesRep(){
		prepareSalesRepData();
		
		// start test as 
		Test.startTest();
		System.runAs( newSalesRep ){
			testLeadCreation();
			//query the account created from lead conversion
			List<Account> acc = [select Id, Name from Account where Id =:convertedLead[0].ConvertedAccountId];
			System.assertNotEquals( null, acc[0].Id, 'lead not converted to account' );
			//query the opportunity created from lead conversion
			opp = [select Id, Name, StageName from Opportunity where  
					Id =:convertedLead[0].ConvertedOpportunityId];
			System.assertNotEquals( null, opp[0].Id, 'lead not converted to opportunity' );
		}
		Test.stopTest();
	}
		
	
	/*
	* Sales Rep
	* change opportunity stage to closed won 
	* system will prevent sales user to closed opp without oppLineitem
	*/
	@isTest(SeeAllData=true)
	static void testOppCantCloseWithoutOppLI_SalesRep(){
		prepareSalesRepData();
		
		// start test as 
		Test.startTest();
		System.runAs( newSalesRep ){
			
            testLeadCreation();
            testInventoryNotcreatedOpenOpp();
			
			//case-2
			//change opportunity stage to closed won 
			//system will prevent sales user to closed opp without oppLineitem
			
			opp = [ Select StageName from Opportunity where Id =:opp[0].Id ];
			opp[0].StageName = 'Closed Won';
            try{
            	OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;	
            	update opp;
            }catch( Exception ex){
            	System.assertEquals( true, ex.getMessage().contains('Opportunity cannot be closed without associated products'));
            }
			opp = [ Select StageName from Opportunity where Id =:opp[0].Id ];
			System.assertEquals( 'Needs Analysis', opp[0].StageName );
		}
		Test.stopTest();
	}
	/*
	* sales rep
	* test-before closed won stage inventory not created 
	*/
	
	@isTest(SeeAllData=true)
	static void testInventorynotCreated_SalesRep(){
		prepareSalesRepData();
		
		// start test as 
		Test.startTest();
		System.runAs( newSalesRep ){
			
            testLeadCreation();
            testInventoryNotcreatedOpenOpp();
            opp = [ Select Name, HasOpportunityLineItem, StageName from Opportunity where Id =:opp[0].Id ];
			System.assertEquals( 'Needs Analysis', opp[0].StageName );
			//check there is no opplineitem
			items = [Select Id from OpportunityLineItem where OpportunityId IN :opp];
			System.assertEquals( true, items.isEmpty(), 'oppli is there' );
			//check there is no inventory
			invnfromopp = [Select Id from Inventory__c where OpportunityN__c IN :opp];
			System.assertEquals( true, invnfromopp.isEmpty(), 'inventory is there' );
            
		}
		Test.stopTest();
	}
	
	/*
	* Sales Rep
	* Create Inventory from Opplineitem
	*/
	@isTest(SeeAllData=true)
	static void testInventoryCreate_SalesRep(){
		prepareSalesRepData();
		
		// start test as 
		Test.startTest();
		System.runAs( newSalesRep ){
			testLeadCreation();
			testInventoryCreationFuture();
			invnfromopp = [Select Id,OppLineItemId__c from Inventory__c where OpportunityN__c IN :opp ];
			System.assertEquals( 6, invnfromopp.size(), 'number of inventory is not equal with the number of opplineitem' );
		}
		Test.stopTest();
	}
	
	
	/*
	* Sales Rep
	* when opp is closed with future close date,
	* sales rep able to change only stage nothing else
	*/
	@isTest(SeeAllData=true)
	static void testOnlyChangeOppStage_SalesRep(){
		prepareSalesRepData();
		
		// start test as 
		Test.startTest();
		System.runAs( newSalesRep ){
			
            testLeadCreation();
			testInventoryCreationFuture();
			//case-5
			//change any other field with or without stagename
			// system will prevent sales user to edit opportunity when it is closed won with future close date,
			// ask sales user to change the opportunity stage to anything else to edit opportunity
			opp = [ Select Name, IsPrivate, StageName from Opportunity where Id =:opp[0].Id ];
			opp[0].StageName = 'Qualification';
			opp[0].Name = 'opptestname';
			opp[0].IsPrivate = true;
			try{
				OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
            	update opp;
            }catch( Exception ex){
            	System.assertEquals( true, ex.getMessage().contains('Only Stage Can Be Changed for closed opportunity'));
            }
            
            //check opportunity not updated
			opp = [ Select Name, IsPrivate, StageName from Opportunity where Id =:opp[0].Id ];
			System.assertEquals('Closed Won', opp[0].StageName);
			System.assertNotEquals('opptestname', opp[0].Name);
			System.assertNotEquals(true, opp[0].IsPrivate);	
		}
		Test.stopTest();
	}
	
	/*
	* Sales Rep
	* change the opportunity stage from closed won to anything else,
    * inventory with new status will be deleted and inventory with shipped status will be changed to on hold
	*/
	@isTest(SeeAllData=true)
	static void testShippedtoOnHoldNewDelete_SalesRep(){
		prepareSalesRepData();
		
		// start test as 
		Test.startTest();
		System.runAs( newSalesRep ){
			
            testLeadCreation();
			testInventoryCreationFuture();
			changeInventorySatusShipped();

			//change opportunity stage to nything else from closed won
			opp = [ Select Name, IsPrivate, StageName from Opportunity where Id =:opp[0].Id ];
			invnfromopp = [Select Status__c from Inventory__c where OpportunityN__c IN :opp ];
			System.assertEquals(6,invnfromopp.size());
			System.assertEquals('Shipped', invnfromopp[0].Status__c );
			System.assertEquals('Shipped', invnfromopp[1].Status__c );
			System.assertEquals('New', invnfromopp[2].Status__c );
			opp[0].StageName = 'Qualification';
			try{
				//for OpportunityAfterUpdateHelper class oppAfterUpdateDone flag will be false 
				//then method to update inventory will happen
				OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
				update opp;
			}catch(Exception ex){
				System.assert( false, 'opportunity stage cannot be changed from closed won to anything else' 
								+ ex.getMessage());
			}
			//check opportunity stage change from closed won to qualification
			opp = [ Select StageName from Opportunity where Id =:opp[0].Id ];
			System.assertEquals('Qualification', opp[0].StageName );
			invnfromopp = [Select Status__c from Inventory__c where OpportunityN__c =:opp[0].Id ];
			System.assertEquals('On Hold', invnfromopp[0].Status__c );
			System.assertEquals( 2,invnfromopp.size(), 'there are more than 2 inventory without on hold status' );
			opp = [ Select Id from Opportunity where Id =:opp[0].Id ];
			invnfromopp = [Select Id from Inventory__c 
							where OpportunityN__c =:opp[0].Id AND Status__c = 'New'];
			System.assertEquals(true, invnfromopp.isEmpty() );
			opp = [ Select StageName from Opportunity where Id =:opp[0].Id ];
			invnfromopp = [Select Status__c from Inventory__c where OpportunityN__c IN :opp ];
			opp[0].StageName = 'Closed Won';
			try{
				OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
				update opp;
			}catch( Exception ex){
            	System.assert( false, 'opportunity stage cannot be moved to closed won' + ex.getMessage());
            }
			//check opportunity stage name chnged to closed won
			opp = [ Select StageName from Opportunity where Id =:opp[0].Id ];
			System.assertEquals('Closed Won', opp[0].StageName );
			
			invnfromopp = [Select Id, Status__c from Inventory__c where OpportunityN__c IN :opp];
			//check inventory created from
			//check number of invntry is 3(as there is oppli with quantity 3)
			System.assertEquals( true, !invnfromopp.isEmpty(), 'inventory is not there' );
			System.assertEquals( 6, invnfromopp.size(), 'number of inventory is not equal with the number of opplineitem' );
			System.assertEquals( 'On Hold', invnfromopp[0].Status__c );
			System.assertEquals( 'On Hold', invnfromopp[1].Status__c );
			System.assertEquals( 'New', invnfromopp[2].Status__c );
		}
		Test.stopTest();
	}
	/*
	* sales rep
	* try to change the field of closed won opportunity with past close date
	* system will prevent sales rep
	* past closed opp cannot be edited
	*/
	@isTest(SeeAllData=true)
	static void testOpportunityPastCantEdit_SalesRep(){
		prepareSalesRepData();
		
		// start test as 
		Test.startTest();
		System.runAs( newSalesRep ){
			
			//case-8
			//try to change the field of closed won opportunity with past close date
			// system will prevent sales rep
			//past closed opp cannot be edited
			createOpportunityOppLIInventoryPast();
			oppu = [ Select Name, IsPrivate, StageName from Opportunity where Id =:oppu[0].Id ];
			oppu[0].StageName = 'Qualification';
			oppu[0].Name = 'opptestname';
			oppu[0].IsPrivate = true;
			oppu[0].CloseDate = Date.today();
			try{
				OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
            	update oppu;
            }catch( Exception ex){
            	System.assertEquals( true, ex.getMessage().contains('Closed Opportunity Cannot be edited(Past Close Date)'));
            }
            
            //check opportunity not updated
			oppu = [ Select Name, IsPrivate, StageName, CloseDate from Opportunity where Id =:oppu[0].Id ];
			System.assertEquals('Closed Won', oppu[0].StageName);
			System.assertNotEquals('opptestname', oppu[0].Name);
			System.assertNotEquals(true, oppu[0].IsPrivate);
			System.assertNotEquals( Date.today(),oppu[0].CloseDate );
             
		}
		Test.stopTest();
	}
	
	/*
	* Sales Manager
	* create lead convert it to account , opportunity
	*/
	@isTest(SeeAllData=true)
	static void testLeadCreation_SalesManager(){
		prepareSalesManagerData();
		
		//start test and run as sales manager
		Test.startTest();
		System.runAs( newSalesManager ){
			testLeadCreation();
			//query the account created from lead conversion
			List<Account> acc = [select Id, Name from Account where Id =:convertedLead[0].ConvertedAccountId];
			System.assertNotEquals( null, acc[0].Id, 'lead not converted to account' );
			//query the opportunity created from lead conversion
			opp = [select Id, Name, StageName from Opportunity where  
					Id =:convertedLead[0].ConvertedOpportunityId];
			System.assertNotEquals( null, opp[0].Id, 'lead not converted to opportunity' );
		}
		Test.stopTest();
	}
	/*
	* sales Manager
	* test-before closed won stage inventory not created 
	*/
	@isTest(SeeAllData=true)
	static void testInventoryNotCreated_SalesManager(){
		prepareSalesManagerData();
		
		//start test and run as sales manager
		Test.startTest();
		System.runAs( newSalesManager ){
			testLeadCreation();
            testInventoryNotcreatedOpenOpp();
            opp = [ Select Name, HasOpportunityLineItem, StageName from Opportunity where Id =:opp[0].Id ];
			System.assertEquals( 'Needs Analysis', opp[0].StageName );
			//check there is no opplineitem
			items = [Select Id from OpportunityLineItem where OpportunityId IN :opp];
			System.assertEquals( true, items.isEmpty(), 'oppli is there' );
			//check there is no inventory
			invnfromopp = [Select Id from Inventory__c where OpportunityN__c IN :opp];
			System.assertEquals( true, invnfromopp.isEmpty(), 'inventory is there' );
		}
		Test.stopTest();
	}
	
	/*
	* sales Manager
	* can close opportunity without associsted product, system will not prevent 
	*
	*/
	@isTest(SeeAllData=true)
	static void testOpportunityClosewithoutOppLI_SalesManager(){
		prepareSalesManagerData();
		
		//start test and run as sales manager
		Test.startTest();
		System.runAs( newSalesManager ){
			testLeadCreation();
			//case-2
			//change opportunity stage to closed won 
			// and change it again to Value Proposition
			opp = [ Select StageName from Opportunity where Id =:opp[0].Id ];
			opp[0].StageName = 'Closed Won';
			try{
				OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
				update opp;
			}catch( Exception ex){
				System.assert( false, 'stage name cannot be changed' + ex.getMessage());
			}
			opp = [ Select StageName from Opportunity where Id =:opp[0].Id ];
			System.assertEquals( 'Closed Won', opp[0].StageName );
			
		}
		Test.stopTest();
	}
	/*
	* Sales Manager
	* test -create Inventory from oppLine item
	*/
	@isTest(SeeAllData=true)
	static void testInventoryCreation_SalesManager(){
		prepareSalesManagerData();
		
		//start test and run as sales manager
		Test.startTest();
		System.runAs( newSalesManager ){
			testLeadCreation();
			
			//case-2
			//create product and add this to stadard pricebook
			//create pricebookentry with previous created product
			//add pricebookentry with opp
			//create opplineitem for opp
			testInventoryCreationFuture();
			invnfromopp = [Select Id,OppLineItemId__c from Inventory__c where OpportunityN__c IN :opp ];
			System.assertEquals( 6, invnfromopp.size(), 'number of inventory is not equal with the number of opplineitem' );
		}
		Test.stopTest();
	}
	/*
	* Sales Manager
	* change any other field with or without stagename
	* system will prevent sales user to edit opportunity when it is closed won with future close date,
	* ask sales user to change the opportunity stage to anything else to edit opportunity
	*/
	@isTest(SeeAllData=true)
	static void testOnlyStageChangeFutureOpp_SalesManager(){
		prepareSalesManagerData();
		
		//start test and run as sales manager
		Test.startTest();
		System.runAs( newSalesManager ){
			testLeadCreation();
			
			//case-3
			//create product and add this to stadard pricebook
			//create pricebookentry with previous created product
			//add pricebookentry with opp
			//create opplineitem for opp
			testInventoryCreationFuture();
			
			//case-5
			//change any other field with or without stagename
			// system will prevent sales user to edit opportunity when it is closed won with future close date,
			// ask sales user to change the opportunity stage to anything else to edit opportunity
			opp = [ Select Name, IsPrivate, StageName from Opportunity where Id =:opp[0].Id ];
			opp[0].StageName = 'Qualification';
			opp[0].Name = 'opptestname';
			opp[0].IsPrivate = true;
			try{
				OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
            	update opp;
            }catch( Exception ex){
            	System.assertEquals( true, ex.getMessage().contains('Only stage can be edited'));
            }
            
            //check opportunity not updated
            opp = [ Select Name, IsPrivate, StageName from Opportunity where Id =:opp[0].Id ];
            System.assertEquals('Closed Won', opp[0].StageName);
            System.assertNotEquals('opptestname', opp[0].Name);
            System.assertNotEquals(true, opp[0].IsPrivate);
		}
		Test.stopTest();
	}
	/*
	* Sales Manager
	* change any other field with or without stagename,
	* system will prevent sales user to edit opportunity when it is closed won with past close date,
	* ask sales user to change the opportunity stage to anything else to edit opportunity
	*/
	@isTest(SeeAllData=true)
	static void testOnlyStageChangePastOpp_SalesManager(){
		prepareSalesManagerData();
		
		//start test and run as sales manager
		Test.startTest();
		System.runAs( newSalesManager ){
			testLeadCreation();
			
			//case-3
			//create product and add this to stadard pricebook
			//create pricebookentry with previous created product
			//add pricebookentry with opp
			//create opplineitem for opp
			createOpportunityOppLIInventoryPast();
			
			//case-5
			//change any other field with or without stagename
			// system will prevent sales user to edit opportunity when it is closed won with future close date,
			// ask sales user to change the opportunity stage to anything else to edit opportunity
			oppu = [ Select Name, IsPrivate, StageName from Opportunity where Id =:oppu[0].Id ];
			oppu[0].StageName = 'Qualification';
			oppu[0].Name = 'opptestname';
			oppu[0].IsPrivate = true;
			try{
				OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
            	update oppu;
            }catch( Exception ex){
            	System.assertEquals( true, ex.getMessage().contains('Only stage can be edited'));
            }
            
            //check opportunity not updated
            oppu = [ Select Name, IsPrivate, StageName from Opportunity where Id =:oppu[0].Id ];
            System.assertEquals('Closed Won', oppu[0].StageName);
            System.assertNotEquals('opptestname', oppu[0].Name);
            System.assertNotEquals(true, oppu[0].IsPrivate);
		}
		Test.stopTest();
	}
	
	/*
	* case-3 test method for sales manager
	* when sales manager change the stage from closed to anything else,
	* opplineitem and inventory related to that opportunity , will be deleted.
	*/
	
	@isTest(SeeAllData=true)
	static void testOpportunityCreateFromLead_SalesManager(){
		prepareSalesManagerData();
		
		//start test and run as sales manager
		Test.startTest();
		System.runAs( newSalesManager ){
			testLeadCreation();
			testInventoryCreationFuture();
			changeInventorySatusShipped();
			//case-6
			//change one inventory status to shipped.
			//then change the opportunity stage from closed won to anything else,
			//all inventory and opplineitem will be delete
			invnfromopp = [Select Status__c from Inventory__c where OpportunityN__c IN :opp ];
			System.assertEquals(6,invnfromopp.size());
			System.assertEquals('Shipped', invnfromopp[0].Status__c );
			System.assertEquals('Shipped', invnfromopp[1].Status__c );
			System.assertEquals('New', invnfromopp[2].Status__c );
			//change opportunity stage to nything else from closed won
			opp = [ Select Name, IsPrivate, StageName from Opportunity where Id =:opp[0].Id ];
			opp[0].StageName = 'Qualification';
			try{
				//for OpportunityAfterUpdateHelper class oppAfterUpdateDone flag will be false 
				//then method to delete inventory and oppline item will happen
				OpportunityAfterUpdateHelper.oppAfterUpdateDone = false;
				update opp;
			}catch(Exception ex){
			System.assert( false, 'opportunity stage cannot be changed from closed won to anything else' 
							+ ex.getMessage());
			}
			//check opportunity stage change from closed won to qualification
			opp = [ Select StageName from Opportunity where Id =:opp[0].Id ];
			System.assertEquals('Qualification', opp[0].StageName );
			//check all inventory and opplineitem deleted
			invnfromopp = [Select Id From Inventory__c where OpportunityN__c =:opp[0].Id ];
			items = [Select Id from OpportunityLineItem where OpportunityId =:opp[0].Id];
			System.assertEquals( true, invnfromopp.isEmpty(), 'there are inventory related to opp' );
			System.assertEquals( true,items.isEmpty(), 'there are many opplineitem without on hold status' );
             
		}
		Test.stopTest();
	}
}