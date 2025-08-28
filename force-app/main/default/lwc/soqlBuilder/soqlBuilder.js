import { LightningElement, track } from 'lwc';
import nlToSoql from '@salesforce/apex/DevCopilotController.nlToSoql';

export default class SoqlBuilder extends LightningElement {
    @track prompt = '';
    @track model = '';
    @track soql = '';

    handleChange(e){ this.prompt = e.detail.value; }
    handleModel(e){ this.model = e.detail.value; }

    async build(){
        this.soql = '';
        if(!this.prompt) return;
        try{
            this.soql = await nlToSoql({ nl: this.prompt, modelName: this.model });
        }catch(err){
            this.soql = 'Error: ' + (err?.body?.message || err?.message);
        }
    }
}
