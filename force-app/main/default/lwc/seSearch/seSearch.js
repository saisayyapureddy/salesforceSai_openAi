import { LightningElement, track } from 'lwc';
import seSearch from '@salesforce/apex/DevCopilotController.seSearch';

export default class SeSearch extends LightningElement {
    @track q='';
    @track items=[];
    handleQ(e){ this.q = e.detail.value; }
    async go(){
        this.items = [];
        if(!this.q) return;
        try{ this.items = await seSearch({ query: this.q }); }
        catch(err){ this.items = [{ title: 'Error', link: '#' }]; }
    }
}
