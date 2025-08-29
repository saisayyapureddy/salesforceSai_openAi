public with sharing class DynamicSoqlController {
    
    /**
     * Get all accessible Salesforce objects including custom objects
     * @return List of ObjectOption wrappers containing all accessible objects
     */
    @AuraEnabled(cacheable=true)
    public static List<ObjectOption> getAllObjects() {
        List<ObjectOption> objectOptions = new List<ObjectOption>();
        
        try {
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            
            for (String objectName : globalDescribe.keySet()) {
                Schema.SObjectType objectType = globalDescribe.get(objectName);
                Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
                
                // Only include accessible objects and exclude system/internal objects
                if (objectDescribe.isAccessible() &&
                    objectDescribe.isQueryable() &&
                    !objectName.endsWith('__Tag') &&
                    !objectName.endsWith('__History') &&
                    !objectName.endsWith('__Share') &&
                    !objectName.startsWith('UserPreferences') &&
                    !objectName.contains('ChangeEvent') &&
                    !objectName.contains('__Feed') &&
                    objectName != 'ContentDocumentLink' &&
                    objectName != 'ContentVersion' &&
                objectName != 'ContentDocument') {
                    
                    ObjectOption option = new ObjectOption();
                    option.label = objectDescribe.getLabel();
                    option.value = objectDescribe.getName();
                    option.isCustom = objectDescribe.isCustom();
                    option.description = objectDescribe.getLabel() + ' - ' + getObjectDescription(objectDescribe.getName());
                    
                    objectOptions.add(option);
                }
            }
            
            // Sort objects: Standard objects first, then custom objects
            objectOptions.sort(new ObjectOptionComparator());
            
            return objectOptions;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving objects: ' + e.getMessage());
        }
    }
    
    /**
     * Get detailed metadata for a Salesforce object including field types and picklist values
     * @param objectName - The API name of the Salesforce object
     * @return ObjectMetadata wrapper containing enhanced field information
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
            
            List<FieldOption> fieldOptions = new List<FieldOption>();
            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                // Only include accessible and queryable fields
                if (fieldDescribe.isAccessible() && !fieldDescribe.isCalculated()) {
                    FieldOption fieldOption = new FieldOption();
                    fieldOption.label = fieldDescribe.getLabel();
                    fieldOption.value = fieldDescribe.getName();
                    fieldOption.type = String.valueOf(fieldDescribe.getType());
                    fieldOption.isIndexed = isIndexedField(fieldDescribe.getName());
                    fieldOption.isRequired = fieldDescribe.isNillable() == false && fieldDescribe.isCreateable();
                    
                    // Enhanced field type detection
                    fieldOption.isDate = isDateField(fieldDescribe.getType());
                    fieldOption.isPicklist = isPicklistField(fieldDescribe.getType());
                    fieldOption.isNumber = isNumberField(fieldDescribe.getType());
                    fieldOption.isBoolean = fieldDescribe.getType() == Schema.DisplayType.BOOLEAN;
                    
                    // Get picklist values if it's a picklist field
                    if (fieldOption.isPicklist) {
                        fieldOption.picklistValues = getPicklistValues(fieldDescribe);
                    }
                    
                    fieldOptions.add(fieldOption);
                }
            }
            
            // Sort fields: Required first, then indexed, then alphabetically
            fieldOptions.sort(new FieldOptionComparator());
            
            ObjectMetadata metadata = new ObjectMetadata();
            metadata.fieldOptions = fieldOptions;
            metadata.description = objectDescribe.getLabel() + ' - ' + getObjectDescription(objectName);
            metadata.recordCount = getApproxRecordCount(objectName);
            
            return metadata;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving object metadata: ' + e.getMessage());
        }
    }
    
    /**
     * Get picklist values for a specific field
     * @param objectName - The API name of the Salesforce object
     * @param fieldName - The API name of the field
     * @return List of PicklistValue wrappers
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistValue> getFieldPicklistValues(String objectName, String fieldName) {
        List<PicklistValue> picklistValues = new List<PicklistValue>();
        
        try {
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
            if (objectType != null) {
                Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
                Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
                
                if (fieldMap.containsKey(fieldName)) {
                    Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                    
                    if (isPicklistField(fieldDescribe.getType())) {
                        List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();
                        for (Schema.PicklistEntry entry : picklistEntries) {
                            if (entry.isActive()) {
                                PicklistValue pickValue = new PicklistValue();
                                pickValue.label = entry.getLabel();
                                pickValue.value = entry.getValue();
                                picklistValues.add(pickValue);
                            }
                        }
                    }
                }
            }
            
            return picklistValues;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving picklist values: ' + e.getMessage());
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
            
            // Check for dangerous operations
            String upperQuery = cleanQuery.toUpperCase();
            if (upperQuery.contains('DELETE') || upperQuery.contains('UPDATE') ||
            upperQuery.contains('INSERT') || upperQuery.contains('UPSERT')) {
                throw new AuraHandledException('Only SELECT queries are allowed');
            }
            
            // Execute the query with governor limit protection
            List<SObject> records = Database.query(cleanQuery);
            
            QueryResult result = new QueryResult();
            result.records = convertToMap(records);
            result.totalSize = records.size();
            result.queryString = cleanQuery;
            result.executionTime = System.currentTimeMillis();
            
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
            'LASTMODIFIEDDATE', 'SYSTEMMODSTAMP', 'RECORDTYPEID'};
            
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
                analysis.suggestions.add('🎯 Use indexed fields in WHERE clause for better performance');
                score -= 30;
            }
            
            if (!upperQuery.contains('LIMIT')) {
                analysis.suggestions.add('⚡ Add LIMIT clause to prevent hitting governor limits');
                score -= 20;
            } else {
                // Check limit value
                Pattern p = Pattern.compile('LIMIT\\s+(\\d+)');
                Matcher m = p.matcher(upperQuery);
                if (m.find()) {
                    Integer limitValue = Integer.valueOf(m.group(1));
                    if (limitValue > 10000) {
                        analysis.suggestions.add('📊 Consider reducing LIMIT for better performance (current: ' + limitValue + ')');
                        score -= 10;
                    }
                }
            }
            
            if (upperQuery.contains('!=') || upperQuery.contains('NOT IN') || upperQuery.contains('NOT LIKE')) {
                analysis.suggestions.add('🚫 Negative operators can impact query performance');
                score -= 25;
            }
            
            Integer fieldCount = countFields(query);
            if (upperQuery.contains('SELECT *') || fieldCount > 15) {
                analysis.suggestions.add('📝 Select only the fields you need (current: ' + fieldCount + ')');
                score -= 15;
            }
            
            if (upperQuery.contains('ORDER BY') && !upperQuery.contains('LIMIT')) {
                analysis.suggestions.add('🔄 Use LIMIT with ORDER BY for consistent results');
                score -= 10;
            }
            
            // Set performance grade
            if (score >= 90) {
                analysis.performanceGrade = 'Excellent';
                analysis.gradeVariant = 'success';
            } else if (score >= 75) {
                analysis.performanceGrade = 'Good';
                analysis.gradeVariant = 'brand';
            } else if (score >= 60) {
                analysis.performanceGrade = 'Fair';
                analysis.gradeVariant = 'warning';
            } else {
                analysis.performanceGrade = 'Poor';
                analysis.gradeVariant = 'error';
            }
            
            analysis.performanceScore = score;
            analysis.explanation = generateQueryExplanation(query);
            analysis.estimatedRecords = estimateQueryResults(query);
            
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
            '🎯 Use indexed fields (Id, Name, OwnerId, CreatedDate) in WHERE clauses',
            '📝 Limit the number of fields returned to only what you need',
            '⚡ Always use LIMIT clause to prevent governor limits (max 50,000)',
            '🔄 Avoid SOQL queries inside loops - bulkify your code',
            '🎛️ Use selective filters to reduce result set size',
            '📊 Consider using aggregate functions like COUNT() when appropriate',
            '🔒 Use bind variables for dynamic values to improve security',
            '🚫 Avoid negative operators (!=, NOT LIKE) when possible',
            '📋 Use ORDER BY with LIMIT for consistent results',
            '🧪 Test queries with large data volumes before deployment'
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
            'Event' => 'Calendar events and meetings',
            'Product2' => 'Products and services your company sells',
            'Campaign' => 'Marketing campaigns and their members'
        };
        
        String description = descriptions.get(objectName);
        if (description != null) {
            return description;
        } else if (objectName.endsWith('__c')) {
            return 'Custom object for your organization';
        } else {
            return 'Standard Salesforce object';
        }
    }
    
    private static Boolean isIndexedField(String fieldName) {
        List<String> indexedFields = new List<String>{
            'Id', 'Name', 'OwnerId', 'CreatedDate', 'LastModifiedDate',
            'SystemModStamp', 'RecordTypeId', 'CreatedById', 'LastModifiedById'
        };
        return indexedFields.contains(fieldName);
    }
    
    private static Boolean isDateField(Schema.DisplayType fieldType) {
        return fieldType == Schema.DisplayType.DATE ||
            fieldType == Schema.DisplayType.DATETIME ||
            fieldType == Schema.DisplayType.TIME;
    }
    
    private static Boolean isPicklistField(Schema.DisplayType fieldType) {
        return fieldType == Schema.DisplayType.PICKLIST ||
            fieldType == Schema.DisplayType.MULTIPICKLIST;
    }
    
    private static Boolean isNumberField(Schema.DisplayType fieldType) {
        return fieldType == Schema.DisplayType.INTEGER ||
            fieldType == Schema.DisplayType.LONG ||
            fieldType == Schema.DisplayType.DOUBLE ||
            fieldType == Schema.DisplayType.CURRENCY ||
            fieldType == Schema.DisplayType.PERCENT;
    }
    
    private static List<PicklistValue> getPicklistValues(Schema.DescribeFieldResult fieldDescribe) {
        List<PicklistValue> picklistValues = new List<PicklistValue>();
        
        if (isPicklistField(fieldDescribe.getType())) {
            List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();
            for (Schema.PicklistEntry entry : picklistEntries) {
                if (entry.isActive()) {
                    PicklistValue pickValue = new PicklistValue();
                    pickValue.label = entry.getLabel();
                    pickValue.value = entry.getValue();
                    picklistValues.add(pickValue);
                }
            }
        }
        
        return picklistValues;
    }
    
    private static Integer getApproxRecordCount(String objectName) {
        try {
            String countQuery = 'SELECT COUNT() FROM ' + objectName + ' LIMIT 1';
            return Database.countQuery(countQuery);
        } catch (Exception e) {
            return 0;
        }
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
                } else if (value instanceof Decimal) {
                    recordMap.put(field, String.valueOf(value));
                } else {
                    recordMap.put(field, value != null ? String.valueOf(value) : '');
                }
            }
            
            results.add(recordMap);
        }
        
        return results;
    }
    
    private static Integer countFields(String query) {
        try {
            String selectClause = query.substring(query.toUpperCase().indexOf('SELECT') + 6, query.toUpperCase().indexOf('FROM')).trim();
            if (selectClause.contains('COUNT(')) {
                return 1;
            }
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
    
    private static String estimateQueryResults(String query) {
        try {
            if (query.toUpperCase().contains('COUNT(')) {
                return '1 result row';
            } else if (query.toUpperCase().contains('LIMIT')) {
                Pattern p = Pattern.compile('LIMIT\\s+(\\d+)');
                Matcher m = p.matcher(query.toUpperCase());
                if (m.find()) {
                    return 'Up to ' + m.group(1) + ' records';
                }
            }
            return 'Variable based on filters';
        } catch (Exception e) {
            return 'Unable to estimate';
        }
    }
    
    // Comparator Classes
    public class ObjectOptionComparator implements Comparator<ObjectOption> {
        public Integer compare(ObjectOption a, ObjectOption b) {
            // Standard objects first, then custom objects
            if (!a.isCustom && b.isCustom) return -1;
            if (a.isCustom && !b.isCustom) return 1;
            return a.label.compareTo(b.label);
        }
    }
    
    public class FieldOptionComparator implements Comparator<FieldOption> {
        public Integer compare(FieldOption a, FieldOption b) {
            // Required fields first, then indexed, then alphabetical
            if (a.isRequired && !b.isRequired) return -1;
            if (!a.isRequired && b.isRequired) return 1;
            if (a.isIndexed && !b.isIndexed) return -1;
            if (!a.isIndexed && b.isIndexed) return 1;
            return a.label.compareTo(b.label);
        }
    }
    
    // Wrapper Classes
    public class ObjectOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Boolean isCustom;
        @AuraEnabled public String description;
    }
    
    public class FieldOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean isIndexed;
        @AuraEnabled public Boolean isRequired;
        @AuraEnabled public Boolean isDate;
        @AuraEnabled public Boolean isPicklist;
        @AuraEnabled public Boolean isNumber;
        @AuraEnabled public Boolean isBoolean;
        @AuraEnabled public List<PicklistValue> picklistValues;
    }
    
    public class PicklistValue {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }
    
    public class ObjectMetadata {
        @AuraEnabled public List<FieldOption> fieldOptions;
        @AuraEnabled public String description;
        @AuraEnabled public Integer recordCount;
    }
    
    public class QueryResult {
        @AuraEnabled public List<Map<String, Object>> records;
        @AuraEnabled public Integer totalSize;
        @AuraEnabled public String queryString;
        @AuraEnabled public Long executionTime;
    }
    
    public class QueryAnalysis {
        @AuraEnabled public String performanceGrade = 'Unknown';
        @AuraEnabled public String gradeVariant = 'brand';
        @AuraEnabled public Integer performanceScore = 0;
        @AuraEnabled public List<String> suggestions = new List<String>();
        @AuraEnabled public String explanation = '';
        @AuraEnabled public String estimatedRecords = '';
    }
}