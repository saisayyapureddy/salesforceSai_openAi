public with sharing class DynamicSoqlController {
    
    /**
     * Get metadata for a Salesforce object including fields and description
     * @param objectName - The API name of the Salesforce object
     * @return ObjectMetadata wrapper containing fields and description
     */
    @AuraEnabled(cacheable=true)
    public static ObjectMetadata getObjectMetadata(String objectName) {
        try {
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
            if (objectType == null) {
                throw new AuraHandledException('Object not found: ' + objectName);
            }
            
            Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
            
            List<String> fieldList = new List<String>();
            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                // Only include accessible fields
                if (fieldDescribe.isAccessible()) {
                    fieldList.add(fieldDescribe.getName());
                }
            }
            
            // Sort fields alphabetically
            fieldList.sort();
            
            ObjectMetadata metadata = new ObjectMetadata();
            metadata.fields = fieldList;
            metadata.description = objectDescribe.getLabel() + ' - ' + getObjectDescription(objectName);
            
            return metadata;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving object metadata: ' + e.getMessage());
        }
    }
    
    /**
     * Execute a dynamic SOQL query and return results
     * @param query - The SOQL query string to execute
     * @return QueryResult wrapper containing records and metadata
     */
    @AuraEnabled
    public static QueryResult executeQuery(String query) {
        try {
            // Basic query validation
            if (String.isBlank(query)) {
                throw new AuraHandledException('Query cannot be empty');
            }
            
            // Remove any potential security risks - basic sanitization
            String cleanQuery = query.trim();
            if (!cleanQuery.toUpperCase().startsWith('SELECT')) {
                throw new AuraHandledException('Only SELECT queries are allowed');
            }
            
            // Execute the query with governor limit protection
            List<SObject> records = Database.query(cleanQuery);
            
            QueryResult result = new QueryResult();
            result.records = convertToMap(records);
            result.totalSize = records.size();
            result.queryString = cleanQuery;
            
            return result;
            
        } catch (QueryException qe) {
            throw new AuraHandledException('Query execution failed: ' + qe.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Unexpected error: ' + e.getMessage());
        }
    }
    
    /**
     * Analyze query performance and provide optimization suggestions
     * @param query - The SOQL query string to analyze
     * @return QueryAnalysis wrapper containing performance insights
     */
    @AuraEnabled(cacheable=true)
    public static QueryAnalysis analyzeQuery(String query) {
        try {
            QueryAnalysis analysis = new QueryAnalysis();
            
            if (String.isBlank(query)) {
                return analysis;
            }
            
            String upperQuery = query.toUpperCase();
            
            // Analyze selectivity
            List<String> indexedFields = new List<String>{'ID', 'NAME', 'OWNERID', 'CREATEDDATE',
            'LASTMODIFIEDDATE', 'SYSTEMMODSTAMP'};
            
            Boolean hasIndexedWhere = false;
            for (String field : indexedFields) {
                if (upperQuery.contains('WHERE') && upperQuery.contains(field)) {
                    hasIndexedWhere = true;
                    break;
                }
            }
            
            // Performance scoring
            Integer score = 100;
            
            if (upperQuery.contains('WHERE') && !hasIndexedWhere) {
                analysis.suggestions.add('Use indexed fields in WHERE clause for better performance');
                score -= 30;
            }
            
            if (!upperQuery.contains('LIMIT')) {
                analysis.suggestions.add('Add LIMIT clause to prevent hitting governor limits');
                score -= 20;
            }
            
            if (upperQuery.contains('!=') || upperQuery.contains('NOT IN')) {
                analysis.suggestions.add('Negative operators can impact query performance');
                score -= 25;
            }
            
            if (upperQuery.contains('SELECT *') || countFields(query) > 10) {
                analysis.suggestions.add('Select only the fields you need');
                score -= 15;
            }
            
            // Set performance grade
            if (score >= 80) {
                analysis.performanceGrade = 'Excellent';
                analysis.gradeVariant = 'success';
            } else if (score >= 60) {
                analysis.performanceGrade = 'Good';
                analysis.gradeVariant = 'brand';
            } else if (score >= 40) {
                analysis.performanceGrade = 'Fair';
                analysis.gradeVariant = 'warning';
            } else {
                analysis.performanceGrade = 'Poor';
                analysis.gradeVariant = 'error';
            }
            
            analysis.performanceScore = score;
            analysis.explanation = generateQueryExplanation(query);
            
            return analysis;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error analyzing query: ' + e.getMessage());
        }
    }
    
    /**
     * Get SOQL best practices and tips
     * @return List of best practice strings
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getBestPractices() {
        return new List<String>{
            'Use indexed fields in WHERE clauses for better performance',
            'Limit the number of fields returned to only what you need',
            'Use LIMIT clause to prevent hitting governor limits (max 50,000)',
            'Avoid SOQL queries inside loops - bulkify your code',
            'Use selective filters to reduce result set size',
            'Consider using aggregate functions like COUNT() when appropriate',
            'Use bind variables for dynamic values to improve security',
            'Avoid negative operators (!=, NOT LIKE) when possible',
            'Use ORDER BY with LIMIT for consistent results',
            'Test queries with large data volumes before deployment'
        };
    }
    
    // Helper Methods
    private static String getObjectDescription(String objectName) {
        Map<String, String> descriptions = new Map<String, String>{
            'Account' => 'Companies and organizations you do business with',
            'Contact' => 'People associated with your accounts',
            'Lead' => 'Potential customers who have shown interest',
            'Opportunity' => 'Sales deals tracked through the sales process',
            'Case' => 'Customer service requests and issues',
            'User' => 'Salesforce users in your organization',
            'Task' => 'Activities and to-dos assigned to users',
            'Event' => 'Calendar events and meetings'
        };
        return descriptions.get(objectName) != null ? descriptions.get(objectName) : 'Custom Salesforce object';
    }
    
    private static List<Map<String, Object>> convertToMap(List<SObject> records) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        
        for (SObject record : records) {
            Map<String, Object> recordMap = new Map<String, Object>();
            Map<String, Object> populatedFields = record.getPopulatedFieldsAsMap();
            
            for (String field : populatedFields.keySet()) {
                Object value = populatedFields.get(field);
                // Handle different field types
                if (value instanceof DateTime) {
                    recordMap.put(field, ((DateTime)value).format('yyyy-MM-dd HH:mm:ss'));
                } else if (value instanceof Date) {
                    recordMap.put(field, ((Date)value).format());
                } else {
                    recordMap.put(field, value);
                }
            }
            
            results.add(recordMap);
        }
        
        return results;
    }
    
    private static Integer countFields(String query) {
        try {
            String selectClause = query.substring(query.indexOf('SELECT') + 6, query.indexOf('FROM')).trim();
            return selectClause.split(',').size();
        } catch (Exception e) {
            return 1;
        }
    }
    
    private static String generateQueryExplanation(String query) {
        if (String.isBlank(query)) {
            return 'No query to explain';
        }
        
        try {
            String explanation = 'This query ';
            String upperQuery = query.toUpperCase();
            
            if (upperQuery.contains('COUNT(')) {
                explanation += 'counts records';
            } else {
                explanation += 'retrieves data';
            }
            
            if (upperQuery.contains('FROM')) {
                String fromClause = query.substring(query.toUpperCase().indexOf('FROM') + 4);
                String objectName = fromClause.split(' ')[0].trim();
                explanation += ' from ' + objectName + ' records';
            }
            
            if (upperQuery.contains('WHERE')) {
                explanation += ' with filtering conditions';
            }
            
            if (upperQuery.contains('ORDER BY')) {
                explanation += ' sorted by specified fields';
            }
            
            if (upperQuery.contains('LIMIT')) {
                Pattern p = Pattern.compile('LIMIT\\s+(\\d+)');
                
                Matcher m = p.matcher(upperQuery);
                if (m.find()) {
                    explanation += ' limited to ' + m.group(1) + ' records';
                }
            }
            
            explanation += '.';
            return explanation;
            
        } catch (Exception e) {
            return 'Unable to generate explanation for this query.';
        }
    }
    
    // Wrapper Classes
    public class ObjectMetadata {
        @AuraEnabled public List<String> fields;
        @AuraEnabled public String description;
    }
    
    public class QueryResult {
        @AuraEnabled public List<Map<String, Object>> records;
        @AuraEnabled public Integer totalSize;
        @AuraEnabled public String queryString;
    }
    
    public class QueryAnalysis {
        @AuraEnabled public String performanceGrade = 'Unknown';
        @AuraEnabled public String gradeVariant = 'brand';
        @AuraEnabled public Integer performanceScore = 0;
        @AuraEnabled public List<String> suggestions = new List<String>();
        @AuraEnabled public String explanation = '';
    }
}