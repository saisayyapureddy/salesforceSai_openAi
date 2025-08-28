public with sharing class TestGenerator {
    @AuraEnabled(cacheable=false)
    public static String generateTest(String apexClassSource, String modelName){
        String sys = 'You are an expert Salesforce Apex test author. Generate a high-quality @isTest class for the provided Apex class. Include setup data, asserts, and cover happy/edge cases. Return ONLY Apex code.';
        return OpenAIService.chat(sys, apexClassSource, modelName);
    }
}
