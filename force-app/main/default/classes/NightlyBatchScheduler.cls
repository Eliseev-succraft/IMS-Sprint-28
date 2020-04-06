public with sharing class NightlyBatchScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new PopulateLateRepaymentFixedFeeBatch());
        Database.executeBatch(new InvestmentsAccrualBatchController());
        Database.executeBatch(new PopulateLoanExpectedAmountBatch());
        Database.executeBatch(new VariableInterestRateBatch(System.today()), 1);
        Database.executeBatch(new LoanHealthCheckBatch(), 1);
    }
}