public with sharing class ApplicationPDFGenerator {

    public static Attachment generateApplicationPDF(Application__c application, String pdfName, String pdfContent) {
        Attachment attachmentPDF = new Attachment();
        try {
            pdfContent = EncodingUtil.urlEncode(pdfContent, 'UTF-8');
            pdfContent = '<HTML><BODY><P>' + pdfContent + '</P></BODY></HTML>';
            attachmentPDF.parentId = application.Id;
            attachmentPDF.Name = pdfName;
            attachmentPDF.body = Blob.toPDF(pdfContent); //This creates the PDF content
            
        } catch (Exception e) {
            application.addError(e.getMessage());
        }
        return attachmentPDF;
    }
   
}