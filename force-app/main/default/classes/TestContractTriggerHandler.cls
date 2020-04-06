@isTest
private class TestContractTriggerHandler {
    @isTest static void test_contract_status_edited() {

        User platformUser = TestUtils.createPlatformUser();
        
        Milestone_Configuration__c mc1 = TestUtils.createNewMilestoneConfiguration('Contract', 'Draft', 'Contract Internal Review', 6);
        Milestone_Configuration__c mc2 = TestUtils.createNewMilestoneConfiguration('Contract', 'Signed - Open', 'Contract External Review', 7);
            
        Application__c app = TestUtils.createNewApplication();
        Contract__c c = new Contract__c(
            Status__c = 'Draft'
        );
        
        // admin creates the setup
        System.runAs(new User(ID = UserInfo.getUserID())){            
            insert new List<SObject>{ mc1, mc2, app };
            c.Application__c = app.Id;
            insert c;

            List<Milestone_History__c> mhList = [
                SELECT Milestone__c, Milestone_Date__c, Days_in_Milestone__c, Contract__c, Application__c, Sequence__c
                FROM Milestone_History__c
                WHERE Contract__c =: c.Id
                ORDER BY Sequence__c DESC
            ];

            System.assertEquals(1, mhList.size());
            System.assertEquals(c.Id, mhList[0].Contract__c);
            System.assertEquals('Contract Internal Review', mhList[0].Milestone__c);
        }
        
        // platform user triggers the logic
        system.runAs(platformUser){
            c.Status__c = 'Signed - Open';
            update c;
        }
        List<Milestone_History__c> mhList2 = [
            SELECT Milestone__c, Milestone_Date__c, Days_in_Milestone__c, Contract__c, Application__c, Sequence__c
            FROM Milestone_History__c
            WHERE Contract__c =: c.Id
            ORDER BY Sequence__c DESC
        ];

        System.assertEquals(2, mhList2.size());
        System.assertEquals(c.Id, mhList2[0].Contract__c);
        System.assertEquals(app.Id, mhList2[0].Application__c);
        System.assertEquals(null, mhList2[1].Days_in_Milestone__c);

    }
}