@IsTest
private class ErrorHandlerTest {

    @IsTest
    static void testLogErrorBasic() {
        Test.startTest();
        try {
            Integer x = 1 / 0;
        } catch (Exception ex) {
            ErrorHandler.logError(ex);
        }
        Test.stopTest(); 

        List<Error_Log__c> logs = [
            SELECT Id, CoreLibrary_Error_Message__c, 
                   CoreLibrary_Class_Name__c, 
                   CoreLibrary_Method_Name__c, 
                   CoreLibrary_User__c
            FROM Error_Log__c
        ];
        System.assert(!logs.isEmpty(), 'Log should be created');
        System.assert(!String.isBlank(logs[0].CoreLibrary_Error_Message__c));
        System.assertEquals(UserInfo.getUserId(), logs[0].CoreLibrary_User__c);
    }

    @IsTest
    static void testLogErrorWithContext() {
        Test.startTest();
        try {
            List<Account> accs = [SELECT Id FROM Account WHERE Name = 'xyz' LIMIT 0];
            Account a = accs[0]; // should throw
        } catch (Exception ex) {
            ErrorHandler.logErrorForRecord(ex, '001xx000003D123', 'Extra Context Info');
        }
        Test.stopTest();

        Error_Log__c logRec = [
            SELECT CoreLibrary_Additional_Context__c 
            FROM Error_Log__c 
            LIMIT 1
        ];
        System.assert(logRec.CoreLibrary_Additional_Context__c.contains('Extra Context Info'));
        System.assert(logRec.CoreLibrary_Additional_Context__c.contains('RecordId=001'));
    }

    @IsTest
    static void testLogErrorFromFlowDynamic() {
        List<String> dynMsgs = new List<String>();
        dynMsgs.add('Dynamic Error at ' + System.now());
        dynMsgs.add('Random Error ID: ' + Math.random());

        Test.startTest();
        ErrorHandler.logErrorFromFlow(dynMsgs);
        Test.stopTest();

        List<Error_Log__c> logs = [
            SELECT CoreLibrary_Error_Message__c, CoreLibrary_Class_Name__c 
            FROM Error_Log__c
        ];
        System.assertEquals(2, logs.size());
        for (Error_Log__c l : logs) {
            System.assertEquals('Flow', l.CoreLibrary_Class_Name__c);
            System.assert(l.CoreLibrary_Error_Message__c.startsWith('Dynamic Error') 
                       || l.CoreLibrary_Error_Message__c.startsWith('Random Error'));
        }
    }

    @IsTest
    static void testQueueableEmptyBranch() {
        Test.startTest();
        System.enqueueJob(new ErrorLogQueueable(new List<Error_Log__c>(), 'corrId123'));
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Error_Log__c]);
    }

    @IsTest
    static void testInnerCatchBlock() {
        Test.startTest();
        try {
            Exception ex = new NullPointerException();
            ErrorHandler.logErrorForRecord(ex, null, null);
        } catch (Exception unexpected) {
            System.assert(false, 'Should not throw: ' + unexpected.getMessage());
        }
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM Error_Log__c]);
    }

    @IsTest
    static void testLogErrorWithContextOnly() {
        Test.startTest();
        try {
            Integer x = 1 / 0;
        } catch (Exception ex) {
            ErrorHandler.logError(ex, 'UnitTestContext');
        }
        Test.stopTest();
    
        Error_Log__c logRec = [
            SELECT CoreLibrary_Additional_Context__c 
            FROM Error_Log__c LIMIT 1
        ];
        System.assert(logRec.CoreLibrary_Additional_Context__c.contains('UnitTestContext'));
    }

    @IsTest
    static void testForceInnerCatchBlock() {
        Test.startTest();
        try {
            Exception ex = new NullPointerException();
            ErrorHandler.logErrorForRecord(ex, null, 'BadDate');
        } catch (Exception unexpected) {
            System.assert(false, 'Should not bubble up: ' + unexpected.getMessage());
        }
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Error_Log__c]);
    }
    @IsTest
    static void testForceFlowCatchBlock() {
        Test.startTest();
        try {
            ErrorHandler.logErrorFromFlow(new List<String>{ 'BadFlow' });
        } catch (Exception unexpected) {
            System.assert(false, 'Should not bubble up: ' + unexpected.getMessage());
        }
        Test.stopTest();
    
        System.assertEquals(0, [SELECT COUNT() FROM Error_Log__c]);
    }
    @IsTest
    static void testForceQueueableCatchBlock() {
        List<Error_Log__c> fakeLogs = new List<Error_Log__c>{
            new Error_Log__c(CoreLibrary_Error_Message__c = 'Queueable test error')
        };
    
        Test.startTest();
        System.enqueueJob(new ErrorLogQueueable(fakeLogs, 'BadQueueable')); 
        Test.stopTest();
    
        System.assertEquals(0, [SELECT COUNT() FROM Error_Log__c]);
    }
	@IsTest
    static void testLogClientError() {
            Test.startTest();
            ErrorHandler.logClientError('Client side test error', 'TestContext');
            Test.stopTest();
    
            List<Error_Log__c> insertedLogs = [
                SELECT Id, CoreLibrary_Error_Message__c, CoreLibrary_Additional_Context__c
                FROM Error_Log__c
            ];
            System.assert(!insertedLogs.isEmpty(), 'Log should have been created');
            System.assertEquals('Script-thrown exception', insertedLogs[0].CoreLibrary_Error_Message__c);
            System.assert(insertedLogs[0].CoreLibrary_Additional_Context__c.contains('TestContext'));
        }  
       
  
    
    @IsTest
    static void testQueueableFailBranch() {
        Error_Log__c goodLog = new Error_Log__c(
            CoreLibrary_User__c = UserInfo.getUserId(),
            CoreLibrary_Error_Message__c = 'Valid',
            CoreLibrary_Execution_Time__c = System.now()
        );

        String tooLong = '';
        for (Integer i = 0; i < 500; i++) {
            tooLong += 'x';
        }
        Error_Log__c badLog = new Error_Log__c(
            CoreLibrary_User__c = UserInfo.getUserId(),
            CoreLibrary_Error_Message__c = 'Invalid',
            CoreLibrary_Execution_Time__c = System.now(),
            CoreLibrary_Method_Name__c = tooLong
        );

        List<Error_Log__c> logs = new List<Error_Log__c>{ goodLog, badLog };

        Test.startTest();
        System.enqueueJob(new ErrorLogQueueable(logs, 'FailBranchTest'));
        Test.stopTest();

        List<Error_Log__c> inserted = [
            SELECT Id
            FROM Error_Log__c
            WHERE CoreLibrary_Correlation_Id__c = 'FailBranchTest'
        ];
        System.assertEquals(1, inserted.size(), 'Only the valid log should insert');
    }
	

   
}