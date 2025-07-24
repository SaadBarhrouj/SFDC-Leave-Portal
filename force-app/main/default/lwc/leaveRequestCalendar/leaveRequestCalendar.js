import { LightningElement, wire, api } from 'lwc';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import fullCalendar from '@salesforce/resourceUrl/fullcalendar_v5';
import getHolidays from '@salesforce/apex/HolidayController.getHolidays';
import getMyLeavesForCalendar from '@salesforce/apex/LeaveRequestController.getMyLeavesForCalendar';
import getApprovedLeavesByManager from '@salesforce/apex/TeamRequestsController.getApprovedLeavesByManager';
import USER_ID from '@salesforce/user/Id';
import { subscribe, MessageContext } from 'lightning/messageService';
import LEAVE_REQUEST_MODIFIED_CHANNEL from '@salesforce/messageChannel/LeaveRequestModifiedChannel__c';

export default class LeaveRequestCalendar extends LightningElement {
    _selectedRequestId;
    @api
    get selectedRequestId() {
        return this._selectedRequestId;
    }
    set selectedRequestId(value) {
        if (value !== this._selectedRequestId) {
            this._selectedRequestId = value;
            if (this.calendar) {
                this.centerCalendarOnSelectedRequest();
                this.processAndDisplayEvents();
            }
        }
    }
    centerCalendarOnSelectedRequest() {
        if (!this.calendar || !this.selectedRequestId) return;
        const selectedReq = this.currentLeaveRequests.find(r => r.Id === this.selectedRequestId);
        if (selectedReq && selectedReq.Start_Date__c) {
            this.calendar.gotoDate(selectedReq.Start_Date__c);
        }
    }
    calendar;
    holidays = [];
    currentLeaveRequests = [];
    _context = 'my';
    _managerId;
    scriptsLoaded = false;
    subscription = null;

    @wire(MessageContext)
    messageContext;

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                LEAVE_REQUEST_MODIFIED_CHANNEL,
                () => this.handleRefresh()
            );
        }
    }

    handleRefresh() {
        console.log('[LeaveRequestCalendar] Received leave request modified message, refreshing leave requests data.');            
        console.log(this._context);
        if (this._context === 'my') {
            this.loadMyRequestsData();
        } else if (this._context === 'team') {
            this.loadTeamRequestsData();
        } else if (this._context === 'managerTeam' && this.managerId) {
            this.loadManagerTeamRequestsData(this.managerId);
        }
    }

    @api
    set managerId(value) {
        if (value && value !== this._managerId) {
            this._managerId = value;
            if (this._context === 'managerTeam') {
                this.loadManagerTeamRequestsData(value);
            }
        }
    }
    get managerId() {
        return this._managerId;
    }
    
    @api
    set context(value) {
        if (value && value !== this._context) {
            this._context = value;
            this.calendar = null; 
            if (value === 'my') {
                this.loadMyRequestsData();
            } else if (value === 'team') {
                this.loadTeamRequestsData();
            } else if (value === 'managerTeam' && this.managerId) {
                this.loadManagerTeamRequestsData(this.managerId);
            }
        }
    }
    get context() {
        return this._context;
    }

    @wire(getHolidays)
    wiredHolidays({ error, data }) {
        if (data) {
            this.holidays = data.map(h => ({
                id: h.Id,
                title: h.Name,
                start: h.Holiday_Date__c,
                allDay: true,
                color: '#28b463'
            }));
            if (this.calendar) {
                this.processAndDisplayEvents();
            }
        } else if (error) {
            console.error('Error loading holidays:', error);
        }
    }
    
    loadMyRequestsData() {
        getMyLeavesForCalendar()
            .then(data => {
                this.currentLeaveRequests = data;
                this.handleDataLoaded();
            })
            .catch(error => console.error('Error loading My Leaves:', error));
    }
    
    loadTeamRequestsData() {
        getApprovedLeavesByManager({ managerId: USER_ID })
            .then(data => {
                console.log('Received Team Data: ', data);
                this.currentLeaveRequests = data;
                this.handleDataLoaded();
            })
            .catch(error => console.error('Error loading Team Requests:', error));
    }

    loadManagerTeamRequestsData(managerId) {
        getApprovedLeavesByManager({ managerId })
            .then(data => {
                this.currentLeaveRequests = data;
                this.handleDataLoaded();
            })
            .catch(error => console.error('Error loading Manager Team Requests:', error));
    }

    handleDataLoaded() {
        if (this.scriptsLoaded && !this.calendar) {
            this.initializeCalendar();
        }
        this.processAndDisplayEvents();
    }

    connectedCallback() {
        this.subscribeToMessageChannel();
        if (this._context === 'team') {
            this.loadTeamRequestsData();
        } else {
            this.loadMyRequestsData();
        }
    }

    renderedCallback() {
        if (this.scriptsLoaded) {
            return;
        }
        this.scriptsLoaded = true;

        Promise.all([
            loadScript(this, fullCalendar + '/main.min.js'),
            loadStyle(this, fullCalendar + '/main.min.css')
        ]).then(() => {
            this.handleDataLoaded();
        }).catch(error => console.error('Error loading FullCalendar:', error));
    }

    initializeCalendar() {
        const calendarEl = this.template.querySelector('.calendar-container');
        if (!calendarEl) return;

        let initialDate = new Date().toISOString().slice(0, 10);
        if (this.selectedRequestId) {
            const selectedReq = this.currentLeaveRequests.find(r => r.Id === this.selectedRequestId);
            if (selectedReq && selectedReq.Start_Date__c) {
                initialDate = selectedReq.Start_Date__c;
            }
        }

        this.calendar = new FullCalendar.Calendar(calendarEl, {
            initialView: 'dayGridMonth',
            initialDate: initialDate,
            headerToolbar: {
                left: 'prev,next today',
                center: 'title',
                right: 'dayGridMonth,dayGridWeek,dayGridYear'
            },
            events: []
        });
        this.calendar.render();
    }
    
    processAndDisplayEvents() {
        if (!this.calendar) return;

        const approvedLeaves = this.currentLeaveRequests.filter(
            req => req.Status__c === 'Approved' || req.Status__c === 'Cancellation Requested'
        );

        let selectedEvent = null;
        if (this.selectedRequestId && this._context === 'managerTeam') {
            const selectedReq = this.currentLeaveRequests.find(r => r.Id === this.selectedRequestId);
            if (selectedReq && !approvedLeaves.some(r => r.Id === selectedReq.Id)) {
                let endDate = new Date(selectedReq.End_Date__c);
                endDate.setUTCDate(endDate.getUTCDate() + 1);
                let correctedEndDate = endDate.toISOString().slice(0, 10);
                let title = '';
                const requesterName = selectedReq.Requester__r ? selectedReq.Requester__r.Name : '';
                title = `${requesterName} : ${selectedReq.Name} : ${selectedReq.Leave_Type__c}`;
                selectedEvent = {
                    id: selectedReq.Id,
                    title: title,
                    start: selectedReq.Start_Date__c,
                    end: correctedEndDate,
                    color: '#e39139',
                    allDay: true
                };
            }
        }

        const formattedEvents = approvedLeaves.map(request => {
            let endDate = new Date(request.End_Date__c);
            endDate.setUTCDate(endDate.getUTCDate() + 1);
            let correctedEndDate = endDate.toISOString().slice(0, 10);
            let title = '';
            if (this._context === 'team' || this._context === 'managerTeam') {
                const requesterName = request.Requester__r ? request.Requester__r.Name : '';
                title = `${requesterName} : ${request.Name} : ${request.Leave_Type__c}`;
            } else {
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

        const allEvents = [...this.holidays, ...formattedEvents];
        if (selectedEvent) {
            allEvents.push(selectedEvent);
        }
        this.calendar.removeAllEvents();
        this.calendar.addEventSource(allEvents);
    }
}