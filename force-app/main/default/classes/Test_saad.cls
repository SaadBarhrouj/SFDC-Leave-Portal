public with sharing class Test_saad {
   
   public List<Contact> getContacts() {
    List<Contact> contacts = [SELECT Id, Name FROM Contact];
    System.Debug('Contacts retrieved successfully');
    return contacts;
    }
}