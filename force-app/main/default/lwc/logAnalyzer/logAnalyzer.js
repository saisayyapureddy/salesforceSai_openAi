import { LightningElement, track } from 'lwc';
import analyzeLog from '@salesforce/apex/DevCopilotController.analyzeLog';

export default class LogAnalyzer extends LightningElement {
    @track text='';
    @track metrics=null;
    handleChange(e){ this.text = e.detail.value; }
    async analyze(){
        if(!this.text) return;
        try{ this.metrics = await analyzeLog({ text: this.text }); }
        catch(err){ this.metrics = { summary: 'Error: ' + (err?.body?.message || err?.message) }; }
    }
}
