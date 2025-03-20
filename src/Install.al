// Advanced Portal Designer
codeunit 58501 "APD Actions Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        APDAction: Record "APD Action Hgd";
    begin
        if not APDAction.Get('ATTACHMENT.DOWNLOAD') then
            AddAction('ATTACHMENT.DOWNLOAD', 'Download Attachment');
        if not APDAction.Get('ATTACHMENT.DOWNLOAD') then
            AddAction('NOTES.ADD', 'Add Notes to sales documents');
        if not APDAction.Get('ATTACHMENT.DOWNLOAD') then
            AddAction('NOTES.EDIT', 'Edit note on sales document');
    end;

    local procedure AddAction(ActionCode: Text; Description: Text)
    var
        APDAction: Record "APD Action Hgd";
    begin
        APDAction.Init();
        APDAction."Web Action" := ActionCode;
        APDAction.Description := Description;
        APDAction."Require Authentication" := true;
        APDAction.Type := APDAction.Type::Codeunit;
        APDAction.Insert();
    end;
}