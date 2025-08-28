import { LightningElement, track } from 'lwc';
import genTest from '@salesforce/apex/DevCopilotController.genTest';

export default class TestGenerator extends LightningElement {
    @track source='';
    @track model='';
    @track output='';
    handleChange(e){ this.source = e.detail.value; }
    handleModel(e){ this.model = e.detail.value; }
    async generate(){
        this.output='';
        if(!this.source) return;
        try{
            this.output = await genTest({ apexClassSource: this.source, modelName: this.model });
        }catch(err){
            this.output = 'Error: ' + (err?.body?.message || err?.message);
        }
    }
}
