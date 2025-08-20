import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class AvatarTypeTemplate extends NavigationMixin(LightningElement) {

    handleNavigate(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: this.url
            }
        });
    }
}