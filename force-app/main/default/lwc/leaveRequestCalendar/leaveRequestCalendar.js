import { LightningElement, wire } from 'lwc';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import fullCalendar from '@salesforce/resourceUrl/fullcalendar_v5';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import LEAVE_DATA_FOR_CALENDAR_CHANNEL from '@salesforce/messageChannel/LeaveDataForCalendarChannel__c';
import getHolidays from '@salesforce/apex/HolidayController.getHolidays';
import getMyLeaves from '@salesforce/apex/LeaveRequestController.getMyLeaves';
import getTeamRequests from '@salesforce/apex/TeamRequestsController.getTeamRequests';

export default class LeaveRequestCalendar extends LightningElement {
    calendar;
    isCalendarInitialized = false;
    subscription = null;
    holidays = [];
    currentLeaveRequests = [];
    currentContext = 'my';

    @wire(MessageContext)
    messageContext;

    @wire(getHolidays)
    wiredHolidays({ error, data }) {
        if (data) {
            this.holidays = data.map(h => ({
                id: h.Id,
                title: h.Name,
                start: h.Holiday_Date__c,
                allDay: true,
                color: '#e39139'
            }));
            this.processAndDisplayEvents(this.currentLeaveRequests);
        }
    }
    
    connectedCallback() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                LEAVE_DATA_FOR_CALENDAR_CHANNEL,
                (message) => this.handleContextChange(message)
            );
        }
        this.loadMyRequestsData();
    }

    disconnectedCallback() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    handleContextChange(message) {
        if (message.context) {
            this.currentContext = message.context;
            if (this.currentContext === 'my') {
                this.loadMyRequestsData();
            } else if (this.currentContext === 'team') {
                this.loadTeamRequestsData();
            }
        }
    }

    loadMyRequestsData() {
        getMyLeaves()
            .then(data => {
                this.currentLeaveRequests = data;
                this.processAndDisplayEvents(this.currentLeaveRequests);
            })
            .catch(error => {
                console.error('Error loading My Leaves for calendar:', error);
            });
    }
    
    loadTeamRequestsData() {
        getTeamRequests()
            .then(data => {
                this.currentLeaveRequests = data;
                this.processAndDisplayEvents(this.currentLeaveRequests);
            })
            .catch(error => {
                console.error('Error loading Team Requests for calendar:', error);
            });
    }



    processAndDisplayEvents(requestsData) {
        if (!this.calendar || !requestsData) return;

        const approvedLeaves = requestsData.filter(req => req.Status__c === 'Approved');
        
        const formattedEvents = approvedLeaves.map(request => {
            let endDate = new Date(request.End_Date__c);
            endDate.setDate(endDate.getUTCDate() + 1);
            let correctedEndDate = endDate.toISOString().slice(0, 10);
            
            // --- MODIFICATION : Le titre change en fonction du contexte ---
            let title = '';
            if (this.currentContext === 'team') {
                const requesterName = request.Requester__r ? request.Requester__r.Name : 'Team';
                title = `${requesterName} : ${request.Leave_Type__c}`;
            } else { // Contexte 'my'
                title = `${request.Name} : ${request.Leave_Type__c}`;
            }

            return {
                id: request.Id,
                title: title,
                start: request.Start_Date__c,
                end: correctedEndDate,
                color: '#0070d2',
                allDay: true
            };
        });

        const allEvents = [...formattedEvents, ...this.holidays];
        this.calendar.removeAllEvents();
        this.calendar.addEventSource(allEvents);
    }
    
    renderedCallback() {
        if (this.isCalendarInitialized) return;
        this.isCalendarInitialized = true;
        Promise.all([
            loadStyle(this, fullCalendar + '/main.min.css'),
            loadScript(this, fullCalendar + '/main.min.js')
        ]).then(() => {
            this.initializeCalendar();
        }).catch(error => console.error(error));
    }

    initializeCalendar() {
        const calendarEl = this.template.querySelector('.calendar-container');
        if(!calendarEl) return;
        this.calendar = new FullCalendar.Calendar(calendarEl, {
            initialView: 'dayGridMonth',
            headerToolbar: {
                left: 'prev,next today', center: 'title', right: 'dayGridMonth,dayGridWeek,dayGridYear'
            },
            events: []
        });
        this.calendar.render();
        this.processAndDisplayEvents(this.currentLeaveRequests);
    }
}