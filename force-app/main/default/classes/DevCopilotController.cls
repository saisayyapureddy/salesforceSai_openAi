public with sharing class DevCopilotController {
    @AuraEnabled(cacheable=false)
    public static String nlToSoql(String nl, String modelName){
        return SOQLBuilder.buildSOQL(nl, modelName);
    }
    @AuraEnabled(cacheable=false)
    public static String genTest(String apexClassSource, String modelName){
        return TestGenerator.generateTest(apexClassSource, modelName);
    }
    @AuraEnabled(cacheable=false)
    public static LogAnalyzer.Metrics analyzeLog(String text){
        return LogAnalyzer.analyze(text);
    }
    @AuraEnabled(cacheable=false)
    public static List<StackExchangeService.Item> seSearch(String query){
        return StackExchangeService.search(query);
    }
    @AuraEnabled(cacheable=false)
    public static List<GitHubService.Release> githubReleases(String owner, String repo){
        return GitHubService.releases(owner, repo);
    }
}
