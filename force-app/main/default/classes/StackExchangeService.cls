public with sharing class StackExchangeService {
    public class Item { @AuraEnabled public String title; @AuraEnabled public String link; }
    public class Resp { public List<Item> items; }

    @AuraEnabled(cacheable=false)
    public static List<Item> search(String query){
        HttpRequest r = new HttpRequest();
        r.setMethod('GET');
        r.setEndpoint('callout:StackExchange_API/2.3/search/advanced?order=desc&sort=relevance&site=salesforce&accepted=True&q=' + EncodingUtil.urlEncode(query,'UTF-8'));
        Http h = new Http();
        HttpResponse res = h.send(r);
        if(res.getStatusCode() >= 200 && res.getStatusCode() < 300){
            Resp rr = (Resp) JSON.deserialize(res.getBody(), Resp.class);
            return rr!=null && rr.items!=null ? rr.items : new List<Item>();
        }
        throw new CalloutException('StackExchange error ' + res.getStatusCode() + ': ' + res.getBody());
    }
}
