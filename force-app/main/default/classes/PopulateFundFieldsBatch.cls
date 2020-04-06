public without sharing class PopulateFundFieldsBatch implements Database.Batchable<SObject>, Database.Stateful {

    public Set<Id> fundIds;
    public PopulateFundFieldsBatch(Set<Id> fundIds) {
        this.fundIds = fundIds;
    }

    Map<Id, tempFundCalcData> fundsMap = new Map<Id, tempFundCalcData>();
    public class tempFundCalcData {
        Decimal investmentPrincipalDisbursed;
        Decimal totalDrawDown;
        Decimal totalFundRepayments;
        Decimal fundCashFlowAmount;
        Decimal interestRepaid;
        Decimal feeRepaid;
        Decimal penaltiesRepaid;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
                SELECT Fund__c, Amount__c, Type__c, Fund_Cashflow_Amount__c, Interest_Amount__c, Fee_Amount__c, Late_Repayment_Fee_Amount__c
                FROM Transaction__c
                WHERE Fund__c IN :fundIds
        ]);
    }
 
    public void execute(Database.BatchableContext bc, List<Transaction__c> scope) {
        for (Transaction__c tr : scope) {
            if (!fundsMap.containsKey(tr.Fund__c)) {
                tempFundCalcData baseFund = new tempFundCalcData();
                baseFund.investmentPrincipalDisbursed = 0;
                baseFund.totalDrawDown = 0;
                baseFund.totalFundRepayments = 0;
                baseFund.fundCashFlowAmount = 0;
                baseFund.interestRepaid = 0;
                baseFund.feeRepaid = 0;
                baseFund.penaltiesRepaid = 0;
                fundsMap.put(tr.Fund__c, baseFund);
            }
            tempFundCalcData baseFund = fundsMap.get(tr.Fund__c);
            switch on tr.Type__c {
                when 'Disbursement' {
                    if (tr.Amount__c != null) baseFund.investmentPrincipalDisbursed += tr.Amount__c;
                    if (tr.Fund_Cashflow_Amount__c != null) baseFund.fundCashFlowAmount += tr.Fund_Cashflow_Amount__c;
                }
                when 'Repayment' {
                    if (tr.Amount__c != null) baseFund.totalFundRepayments += tr.Amount__c;
                    if (tr.Fund_Cashflow_Amount__c != null) baseFund.fundCashFlowAmount += tr.Fund_Cashflow_Amount__c;
                    if (tr.Interest_Amount__c != null) baseFund.interestRepaid += tr.Interest_Amount__c;
                    if (tr.Fee_Amount__c != null) baseFund.feeRepaid += tr.Fee_Amount__c;
                    if (tr.Late_Repayment_Fee_Amount__c != null) baseFund.penaltiesRepaid += tr.Late_Repayment_Fee_Amount__c;
                }
                when 'Fund Drawdown' {
                    if (tr.Amount__c != null) baseFund.totalDrawDown += tr.Amount__c;
                    if (tr.Fund_Cashflow_Amount__c != null) baseFund.fundCashFlowAmount += tr.Fund_Cashflow_Amount__c;
                }
                when 'Fund Repayment' {
                    if (tr.Amount__c != null) baseFund.totalFundRepayments += tr.Amount__c;
                    if (tr.Fund_Cashflow_Amount__c != null) baseFund.fundCashFlowAmount += tr.Fund_Cashflow_Amount__c;
                }
            }
            fundsMap.put(tr.Fund__c, baseFund);
        }
    }

    public void finish(Database.BatchableContext bc) {
        List<Fund__c> funds = [
                SELECT Investment_Principal_Disbursed__c, Total_Draw_Down__c, Total_Fund_Repayments__c, Fund_Balance__c, Interest_Repaid__c, Fees_Paid__c, Penalties_Paid__c
                FROM Fund__c
                WHERE Id IN :fundsMap.keySet()
        ];
        for (Fund__c fd : funds) {
            if (fundsMap.containsKey(fd.Id)) {
                tempFundCalcData baseFund = fundsMap.get(fd.Id);
                fd.Investment_Principal_Disbursed__c = baseFund.investmentPrincipalDisbursed;
                fd.Total_Draw_Down__c = baseFund.totalDrawDown;
                fd.Total_Fund_Repayments__c = baseFund.totalFundRepayments;
                fd.Fund_Balance__c = baseFund.fundCashFlowAmount;
                fd.Interest_Repaid__c = baseFund.interestRepaid;
                fd.Fees_Paid__c = baseFund.feeRepaid;
                fd.Penalties_Paid__c = baseFund.penaltiesRepaid;
            }
        }
        update funds;
    }
}