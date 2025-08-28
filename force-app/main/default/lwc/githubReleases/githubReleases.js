import { LightningElement, track } from 'lwc';
import githubReleases from '@salesforce/apex/DevCopilotController.githubReleases';

export default class GithubReleases extends LightningElement {
    @track owner='trailheadapps';
    @track repo='dreamhouse-lwc';
    @track releases=[];

    handleOwner(e){ this.owner = e.detail.value; }
    handleRepo(e){ this.repo = e.detail.value; }

    async fetchReleases(){
        this.releases = [];
        try { this.releases = await githubReleases({ owner: this.owner, repo: this.repo }); }
        catch(err){ this.releases = [{ name:'Error', tag_name:'', html_url:'#', body: (err?.body?.message || err?.message) }]; }
    }
}
