public with sharing class SOQLBuilder {
    @AuraEnabled(cacheable=false)
    public static String buildSOQL(String naturalLanguage, String modelName){
        String systemPrompt = 'You are a Salesforce SOQL assistant. Given user natural language, output ONLY a single valid SOQL query. No explanations.';
        return OpenAIService.chat(systemPrompt, naturalLanguage, modelName);
    }
}
