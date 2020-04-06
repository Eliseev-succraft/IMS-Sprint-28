/**
 * @description         This is the abstract trigger handler. It's purpose is to work out which method in 
 *                      a trigger handler to call depending on the context of the executing trigger.
 * @author              Guy Clairbois
 */
public abstract class TriggerHandler {
    // not in use

    // /**
    //  * @description When set to true will prevent the trigger handler being executed more than once
    //  */
    // private static Boolean preventRecursiveTrigger = false;
    
    // /**
    //  * @description These 4 Maps and Lists will contain the Trigger variables (assigned in Execute method) 
    //  */    
    // protected Map<Id,SObject> oldMap;
    // protected Map<Id,SObject> newMap;
    // protected List<SObject> oldList;
    // protected List<SObject> newList;
    
    // /**
    //  * @description Used to prevent the trigger handler from being executed more than once
    //  */
    // private static Boolean hasExecuted = false;
    
    
    // /**
    //  * @description This will be called in the trigger before insert event
    //  * @param newObjects List of new sObjects to be inserted
    //  */
    // public virtual void beforeInsert(){}
    
    
    // /**
    //  * @description This will be called in the trigger before update event
    //  * @param oldObjects List of the sObjects being updated with their original values
    //  * @param newObjects List of the sObjects being updated with their new values
    //  */
    // public virtual void beforeUpdate(){}


    // /**
    //  * @description This will be called in the trigger before delete event
    //  * @param objects List of the sObjects being deleted
    //  */
    // public virtual void beforeDelete(){}


    // /**
    //  * @description This will be called in the trigger after insert event
    //  * @param newObjects List of the sObjects being inserted
    //  */
    // public virtual void afterInsert(){}
    
    
    // /**
    //  * @description This will be called in the trigger after update event
    //  * @param oldObjects List of the sObjects being updated with their original values
    //  * @param newObjects List of the sObjects being updated with their new values
    //  */
    // public virtual void afterUpdate(){}


    // /**
    //  * @description This will be called in the trigger after delete event
    //  * @param objects List of objects to be deleted
    //  */
    // public virtual void afterDelete(){}


    // /**
    //  * @description This will call the relevant method in the trigger handler for the current trigger event
    //  */
    // public void execute(){
    //     this.oldMap = Trigger.oldMap;
    //     this.newMap = Trigger.newMap;
    //     this.newList = Trigger.new;
    //     this.oldList = Trigger.old;
        
    //     // Control recursive triggers, if required
    //     if(hasExecuted && preventRecursiveTrigger) return;
        
    //     hasExecuted = true;
        
    //     // Call the relevant trigger event method
    //     if(Trigger.isBefore){               
    //         if(Trigger.isDelete){
    //             beforeDelete();
                
    //         } else if (Trigger.isInsert){
    //             beforeInsert();
                
    //         } else if (Trigger.isUpdate){
    //             beforeUpdate();
                
    //         }
    //     } else {
    //         if(Trigger.isDelete){
    //             afterDelete();
                
    //         } else if(Trigger.isInsert){
    //             afterInsert();
                
    //         } else if(Trigger.isUpdate){
    //             afterUpdate();
                
    //         }
    //     }
    // }

}