public with sharing class GitHubService {
    public class Release { @AuraEnabled public String name; @AuraEnabled public String tag_name; @AuraEnabled public String html_url; @AuraEnabled public String body; }

    @AuraEnabled(cacheable=false)
    public static List<Release> releases(String owner, String repo){
        HttpRequest r = new HttpRequest();
        r.setMethod('GET');
        r.setEndpoint('callout:GitHub_API/repos/' + owner + '/' + repo + '/releases');
        r.setHeader('Accept','application/vnd.github+json');
        Http h = new Http();
        HttpResponse res = h.send(r);
        if(res.getStatusCode() >= 200 && res.getStatusCode() < 300){
            List<Release> out = (List<Release>) JSON.deserialize(res.getBody(), List<Release>.class);
            return out==null ? new List<Release>() : out;
        }
        throw new CalloutException('GitHub error ' + res.getStatusCode() + ': ' + res.getBody());
    }
}
