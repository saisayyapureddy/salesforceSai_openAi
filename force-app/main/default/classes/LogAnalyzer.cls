public with sharing class LogAnalyzer {
    public class Metrics {
        @AuraEnabled public Integer soql = 0;
        @AuraEnabled public Integer dml = 0;
        @AuraEnabled public Integer queryRows = 0;
        @AuraEnabled public Integer scriptStatements = 0;
        @AuraEnabled public Integer heapBytes = 0;
        @AuraEnabled public String summary;
    }

    @AuraEnabled(cacheable=false)
    public static Metrics analyze(String debugLogText){
        Metrics m = new Metrics();
        if(String.isBlank(debugLogText)){
            m.summary = 'No log text provided.'; return m;
        }
        List<String> lines = debugLogText.split('\n');
        for(String line: lines){
            if(line.contains('|SOQL_EXECUTE_BEGIN')) m.soql++;
            if(line.contains('|DML_BEGIN')) m.dml++;
            if(line.contains('Number of rows:')){
                Integer idx = line.lastIndexOf('Number of rows:');
                if(idx > -1){
                    String tail = line.substring(idx).replace('Number of rows:','').trim();
                    Integer rows;
                    try { rows = Integer.valueOf(tail.split(' ')[0]); } catch(Exception e) { rows = 0; }
                    m.queryRows += rows;
                }
            }
            if(line.contains('CUMULATIVE_LIMIT_USAGE')){
                if(line.contains('Script statements:')){
                    m.scriptStatements += parseIntSafe(after(line,'Script statements:'));
                }
                if(line.contains('Heap size:')){
                    m.heapBytes += parseIntSafe(after(line,'Heap size:'))*1024;
                }
            }
        }
        m.summary = 'SOQLs: ' + m.soql + ', DMLs: ' + m.dml + ', Rows: ' + m.queryRows + ', Script Statements: ' + m.scriptStatements + ', Heap(bytes): ' + m.heapBytes;
        return m;
    }

    private static Integer parseIntSafe(String s){
        try { return Integer.valueOf( s.replaceAll('[^0-9]','') ); } catch(Exception e){ return 0; }
    }
    private static String after(String s, String token){
        Integer i = s.indexOf(token);
        return i>-1 ? s.substring(i+token.length()) : '';
    }
}
