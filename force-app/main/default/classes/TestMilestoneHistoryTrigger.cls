@isTest
private class TestMilestoneHistoryTrigger {
    @isTest static void test_countDaysInMilestone() {
        Milestone_Configuration__c mc1 = TestUtils.createNewMilestoneConfiguration('Application', 'Enquiry', 'Expression of Interest', 1);
        Milestone_Configuration__c mc2 = TestUtils.createNewMilestoneConfiguration('Application', 'Application', 'Application', 2);
        Milestone_Configuration__c mc3 = TestUtils.createNewMilestoneConfiguration('Application', 'Application Review', 'Application Review', 3);
        Milestone_Configuration__c mc4 = TestUtils.createNewMilestoneConfiguration('Contract', 'Internal Review', 'Contract Internal Review', 6);
        Milestone_Configuration__c mc5 = TestUtils.createNewMilestoneConfiguration('Investment', 'Active', 'Investment Active', 9);
        Application__c app = TestUtils.createNewApplication();
        app.Stage__c = 'Enquiry';
        insert new List<SObject>{ mc1, mc2, mc3, mc4, mc5, app };
        
        app.Stage__c = 'Application';
        update app; 

        app.Stage__c = 'Application Review';
        update app;

        List<Milestone_History__c> mhList = [
            SELECT Milestone_Date__c
            FROM Milestone_History__c
            ORDER BY Sequence__c ASC
        ];

        Integer days1 = 30;
        Integer days2 = 15;
        Date date1 = System.today().addDays(-days1);
        Date date2 = System.today().addDays(-days2);
        mhList[0].Milestone_Date__c = date1;
        mhList[1].Milestone_Date__c = date2;
       
        update new List<Milestone_History__c>{mhList[0], mhList[1]};

        mhList = [
            SELECT Days_in_Milestone__c, Milestone_Date__c
            FROM Milestone_History__c
            ORDER BY Sequence__c ASC
        ];

        // verify results
        System.assertEquals(3, mhList.size());
        System.assertEquals(date1.daysBetween(date2), mhList[0].Days_in_Milestone__c);
        System.assertEquals(date2.daysBetween(System.today()), mhList[1].Days_in_Milestone__c);
        System.assertEquals(null, mhList[2].Days_in_Milestone__c);

        Integer days3 = 10;
        Date date3 = System.today().addDays(-days3);
        mhList[1].Milestone_Date__c = date3;
        update mhList[1];

        List<Milestone_History__c> mhList2 = [
            SELECT Days_in_Milestone__c
            FROM Milestone_History__c
            ORDER BY Sequence__c ASC
        ];

        // verify results
        System.assertEquals(date1.daysBetween(date3), mhList2[0].Days_in_Milestone__c);
        System.assertEquals(date3.daysBetween(System.today()), mhList2[1].Days_in_Milestone__c);
        System.assertEquals(null, mhList2[2].Days_in_Milestone__c);

        // test after delete
        delete mhList2[2];

        List<Milestone_History__c> mhList3 = [
            SELECT Days_in_Milestone__c
            FROM Milestone_History__c
            ORDER BY Sequence__c ASC
        ];

        // verify results
        System.assertEquals(2, mhList3.size());
        System.assertEquals(date1.daysBetween(date3), mhList3[0].Days_in_Milestone__c);
        System.assertEquals(null, mhList3[1].Days_in_Milestone__c);

        // test after undelete
        undelete [SELECT Id FROM Milestone_History__c WHERE Id =: mhList2[2].Id ALL ROWS];

        List<Milestone_History__c> mhList4 = [
            SELECT Days_in_Milestone__c
            FROM Milestone_History__c
            ORDER BY Sequence__c ASC
        ];

        // verify results
        System.assertEquals(3, mhList4.size());
        System.assertEquals(date1.daysBetween(date3), mhList4[0].Days_in_Milestone__c);
        System.assertEquals(date3.daysBetween(System.today()), mhList4[1].Days_in_Milestone__c);
        System.assertEquals(null, mhList4[2].Days_in_Milestone__c);

        // // test moving to the previous stage
        // // move within the same object
        // app.Stage__c = 'Application';
        // update app;

        // List<Milestone_History__c> mhList5 = [
        //     SELECT Days_in_Milestone__c
        //     FROM Milestone_History__c
        //     ORDER BY Sequence__c ASC
        // ];

        // // verify results
        // System.assertEquals(2, mhList5.size());
        // System.assertEquals(date1.daysBetween(System.today()), mhList5[0].Days_in_Milestone__c);
        // System.assertEquals(null, mhList5[1].Days_in_Milestone__c);

        // insert new Contract__c(Application__c = app.Id, Status__c = 'Internal Review');

        // app.Stage__c = 'Enquiry';
        
        // // Perform test
        // Database.SaveResult result = Database.update(app, false);

        // // Verify 
        // // In this case the update should have been stopped by the trigger,
        // // so verify that we got back an error.
        
        // System.assert(!result.isSuccess());
        // System.assert(result.getErrors().size() > 0);
        // System.assertEquals('An error occurred while trying to insert new Milestone History records: ' + 
        //     'This stage update interferes with a milestone on a related object: Contract' +
        //     ' - Contract Internal Review - ' + System.today().format() + '. Please undo the milestone ' + 
        //     'on the related object before you can apply this stage update.', result.getErrors()[0].getMessage());

        
        // Investment__c i = TestUtils.createNewLoan(System.today(), System.today());
        // i.Application__c = app.Id;
        // i.Status__c = 'Active';
        // insert i;

        // // Perform test
        // Database.SaveResult result2 = Database.update(app, false);
        // // Verify 
        // // In this case the update should have been stopped by the trigger,
        // // so verify that we got back an error.
        
        // System.assert(!result2.isSuccess());
        // System.assert(result2.getErrors().size() > 0);
        // System.assertEquals('An error occurred while trying to insert new Milestone History records: ' + 
        //     'This stage update interferes with a milestone on a related object: Investment' +
        //     ' - Investment Active - ' + System.today().format() + '. Please undo the milestone ' + 
        //     'on the related object before you can apply this stage update.', result2.getErrors()[0].getMessage());
    }

    // @isTest static void test_runValidations() {
    //     Milestone_Configuration__c mc1 = TestUtils.createNewMilestoneConfiguration('Application', 'Enquiry', 'Expression of Interest', 1);
    //     Milestone_Configuration__c mc2 = TestUtils.createNewMilestoneConfiguration('Application', 'Application', 'Application', 2);
    //     Milestone_Configuration__c mc3 = TestUtils.createNewMilestoneConfiguration('Application', 'Application Review', 'Application Review', 3);
    //     Application__c app = TestUtils.createNewApplication();
    //     app.Stage__c = 'Enquiry';
    //     insert new List<SObject>{ mc1, mc2, mc3, app };
        
    //     app.Stage__c = 'Application';
    //     update app; 

    //     app.Stage__c = 'Application Review';
    //     update app;

    //     List<Milestone_History__c> mhList = [
    //         SELECT Milestone_Date__c
    //         FROM Milestone_History__c
    //         ORDER BY Sequence__c ASC
    //     ];

    //     Integer days1 = 30;
    //     Date date1 = System.today().addDays(-days1);
    //     mhList[0].Milestone_Date__c = date1;
       
    //     update mhList[0];

    //     // test when the Milestone Date is not correct
    //     Integer days2 = 45;
    //     Date date2 = System.today().addDays(-days2);
    //     mhList[1].Milestone_Date__c = date2;
        
    //     // Perform test
    //     Database.SaveResult result = Database.update(mhList[1], false);
    //     // Verify 
    //     // In this case the update should have been stopped by the trigger,
    //     // so verify that we got back an error.
        
    //     System.assert(!result.isSuccess());
    //     System.assert(result.getErrors().size() > 0);
    //     System.assertEquals('The Milestone Date must not be earlier than the Milestone Date of the previous Milestone History (' +
    //         mhList[0].Milestone_Date__c.format() + ').', result.getErrors()[0].getMessage());
        
    //     Integer days3 = 15;
    //     Date date3 = System.today().addDays(days3);
    //     mhList[1].Milestone_Date__c = date3;

    //     // Perform test
    //     Database.SaveResult result2 = Database.update(mhList[1], false);
    //     // Verify 
    //     // In this case the update should have been stopped by the trigger,
    //     // so verify that we got back an error.
        
    //     System.assert(!result2.isSuccess());
    //     System.assert(result2.getErrors().size() > 0);
    //     System.assertEquals('The Milestone Date must not be later than the Milestone Date of the next Milestone History (' +
    //         [SELECT Milestone_Date__c FROM Milestone_History__c ORDER BY Sequence__c DESC LIMIT 1].Milestone_Date__c.format() + ').', 
    //         result2.getErrors()[0].getMessage());
    // }
}