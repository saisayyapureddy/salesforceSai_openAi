@isTest
public class DynamicSoqlControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create test accounts
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            testAccounts.add(new Account(
                Name = 'Test Account ' + i,
            Industry = 'Technology',
            AnnualRevenue = 100000 * (i + 1)
                ));
        }
        insert testAccounts;
        
        // Create test contacts
        List<Contact> testContacts = new List<Contact>();
        for (Account acc : testAccounts) {
            testContacts.add(new Contact(
                FirstName = 'Test',
            LastName = 'Contact ' + testContacts.size(),
            Email = 'test' + testContacts.size() + '@example.com',
            AccountId = acc.Id
                ));
        }
        insert testContacts;
    }
    
    @isTest
    static void testGetObjectMetadata_Account() {
        Test.startTest();
        
        // Test Account metadata retrieval
        DynamicSoqlController.ObjectMetadata metadata = DynamicSoqlController.getObjectMetadata('Account');
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, metadata, 'Metadata should not be null');
        System.assertNotEquals(null, metadata.fields, 'Fields list should not be null');
        System.assert(metadata.fields.size() > 0, 'Fields list should not be empty');
        System.assert(metadata.fields.contains('Id'), 'Should contain Id field');
        System.assert(metadata.fields.contains('Name'), 'Should contain Name field');
        System.assertNotEquals(null, metadata.description, 'Description should not be null');
    }
    
    @isTest
    static void testGetObjectMetadata_Contact() {
        Test.startTest();
        
        // Test Contact metadata retrieval
        DynamicSoqlController.ObjectMetadata metadata = DynamicSoqlController.getObjectMetadata('Contact');
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, metadata, 'Metadata should not be null');
        System.assert(metadata.fields.contains('Email'), 'Should contain Email field');
        System.assert(metadata.fields.contains('FirstName'), 'Should contain FirstName field');
    }
    
    @isTest
    static void testGetObjectMetadata_InvalidObject() {
        Test.startTest();
        
        try {
            DynamicSoqlController.getObjectMetadata('InvalidObject__c');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Object not found'), 'Should contain object not found message');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testExecuteQuery_SimpleSelect() {
        Test.startTest();
        
        // Test simple SELECT query
        String query = 'SELECT Id, Name FROM Account LIMIT 5';
        DynamicSoqlController.QueryResult result = DynamicSoqlController.executeQuery(query);
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.records, 'Records should not be null');
        System.assertEquals(5, result.totalSize, 'Should return 5 records');
        System.assertEquals(query, result.queryString, 'Query string should match');
        
        // Check record structure
        if (result.records.size() > 0) {
            Map<String, Object> firstRecord = result.records[0];
            System.assert(firstRecord.containsKey('Id'), 'Record should contain Id');
            System.assert(firstRecord.containsKey('Name'), 'Record should contain Name');
        }
    }
    
    @isTest
    static void testExecuteQuery_WithWhere() {
        Test.startTest();
        
        // Test query with WHERE clause
        String query = 'SELECT Id, Name, Industry FROM Account WHERE Industry = \'Technology\'';
        DynamicSoqlController.QueryResult result = DynamicSoqlController.executeQuery(query);
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(5, result.totalSize, 'Should return 5 technology accounts');
    }
    
    @isTest
    static void testExecuteQuery_ContactsWithJoin() {
        Test.startTest();
        
        // Test query with relationship
        String query = 'SELECT Id, FirstName, LastName, Account.Name FROM Contact LIMIT 3';
        DynamicSoqlController.QueryResult result = DynamicSoqlController.executeQuery(query);
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(3, result.totalSize, 'Should return 3 contacts');
    }
    
    @isTest
    static void testExecuteQuery_EmptyQuery() {
        Test.startTest();
        
        try {
            DynamicSoqlController.executeQuery('');
            System.assert(false, 'Should have thrown an exception for empty query');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Query cannot be empty'), 'Should contain empty query message');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testExecuteQuery_InvalidQuery() {
        Test.startTest();
        
        try {
            DynamicSoqlController.executeQuery('DELETE FROM Account');
            System.assert(false, 'Should have thrown an exception for non-SELECT query');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Only SELECT queries are allowed'), 'Should contain SELECT only message');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testExecuteQuery_MalformedQuery() {
        Test.startTest();
        
        try {
            DynamicSoqlController.executeQuery('SELECT InvalidField FROM Account');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Query execution failed'), 'Should contain execution failed message');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testAnalyzeQuery_GoodQuery() {
        Test.startTest();
        
        // Test analysis of a good query
        String query = 'SELECT Id, Name FROM Account WHERE Id != null LIMIT 10';
        DynamicSoqlController.QueryAnalysis analysis = DynamicSoqlController.analyzeQuery(query);
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, analysis, 'Analysis should not be null');
        System.assertNotEquals(null, analysis.performanceGrade, 'Performance grade should not be null');
        System.assert(analysis.performanceScore >= 0, 'Performance score should be non-negative');
        System.assertNotEquals(null, analysis.suggestions, 'Suggestions should not be null');
        System.assertNotEquals(null, analysis.explanation, 'Explanation should not be null');
    }
    
    @isTest
    static void testAnalyzeQuery_PoorQuery() {
        Test.startTest();
        
        // Test analysis of a poor query (no indexed fields, no limit, negative operator)
        String query = 'SELECT * FROM Account WHERE Industry != \'Technology\'';
        DynamicSoqlController.QueryAnalysis analysis = DynamicSoqlController.analyzeQuery(query);
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, analysis, 'Analysis should not be null');
        System.assert(analysis.suggestions.size() > 0, 'Should have suggestions for poor query');
        System.assert(analysis.performanceScore < 100, 'Poor query should have lower score');
    }
    
    @isTest
    static void testAnalyzeQuery_EmptyQuery() {
        Test.startTest();
        
        // Test analysis of empty query
        DynamicSoqlController.QueryAnalysis analysis = DynamicSoqlController.analyzeQuery('');
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, analysis, 'Analysis should not be null for empty query');
    }
    
    @isTest
    static void testGetBestPractices() {
        Test.startTest();
        
        // Test best practices retrieval
        List<String> practices = DynamicSoqlController.getBestPractices();
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, practices, 'Best practices should not be null');
        System.assert(practices.size() > 0, 'Should have at least one best practice');
        
        // Check for key best practices
        Boolean hasIndexedFieldTip = false;
        Boolean hasLimitTip = false;
        Boolean hasBulkifyTip = false;
        
        for (String practice : practices) {
            if (practice.contains('indexed fields')) {
                hasIndexedFieldTip = true;
            }
            if (practice.contains('LIMIT clause')) {
                hasLimitTip = true;
            }
            if (practice.contains('loops')) {
                hasBulkifyTip = true;
            }
        }
        
        System.assert(hasIndexedFieldTip, 'Should include indexed fields tip');
        System.assert(hasLimitTip, 'Should include LIMIT tip');
        System.assert(hasBulkifyTip, 'Should include bulkify tip');
    }
    
    @isTest
    static void testCountFunction() {
        Test.startTest();
        
        // Test COUNT() query
        String query = 'SELECT COUNT() FROM Account';
        DynamicSoqlController.QueryResult result = DynamicSoqlController.executeQuery(query);
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.totalSize, 'COUNT query should return 1 row');
    }
    
    @isTest
    static void testComplexQuery() {
        Test.startTest();
        
        // Test complex query with multiple clauses
        String query = 'SELECT Id, Name, Industry, AnnualRevenue FROM Account WHERE Industry = \'Technology\' ORDER BY Name ASC LIMIT 5 OFFSET 0';
        DynamicSoqlController.QueryResult result = DynamicSoqlController.executeQuery(query);
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.totalSize <= 5, 'Should respect LIMIT clause');
    }
}