@isTest
private class SampleTestUnitTest {

    @isTest
    static void myUnitTest() {
        String result = SampleTest.getMessage();
        System.Assert.areEqual(result,'Hello!!!');
    }
}