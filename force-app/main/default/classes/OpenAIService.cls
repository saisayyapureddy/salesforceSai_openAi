public with sharing class OpenAIService {
    public class ChatRequest {
        public String model;
        public List<Message> messages;
        public Integer max_tokens;
        public Double temperature;
    }
    public class Message {
        public String role;
        public String content;
        public Message(){}
        public Message(String r, String c){ role=r; content=c; }
    }
    public class ChatChoice {
        public Message message;
        public Integer index;
    }
    public class ChatResponse {
        public List<ChatChoice> choices;
    }

    @AuraEnabled(cacheable=false)
    public static String chat(String systemPrompt, String userPrompt, String modelName){
        ChatRequest req = new ChatRequest();
        req.model = String.isBlank(modelName) ? 'gpt-4o-mini' : modelName;
        req.max_tokens = 800;
        req.temperature = 0.2;
        req.messages = new List<Message>{
            new Message('system', systemPrompt),
            new Message('user', userPrompt)
        };
        HttpRequest httpReq = new HttpRequest();
        httpReq.setMethod('POST');
        httpReq.setEndpoint('callout:OpenAI_API/v1/chat/completions');
        httpReq.setHeader('Content-Type', 'application/json');
        httpReq.setBody(JSON.serialize(req));
        Http http = new Http();
        HTTPResponse res = http.send(httpReq);
        if(res.getStatusCode() >= 200 && res.getStatusCode() < 300){
            ChatResponse cr = (ChatResponse) JSON.deserialize(res.getBody(), ChatResponse.class);
            if(cr != null && cr.choices != null && !cr.choices.isEmpty()){
                return cr.choices[0].message != null ? cr.choices[0].message.content : '';
            }
            return '';
        }
        throw new CalloutException('OpenAI error ' + res.getStatusCode() + ': ' + res.getBody());
    }
}
