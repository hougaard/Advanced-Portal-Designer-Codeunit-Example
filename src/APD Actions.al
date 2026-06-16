//
codeunit 58500 "APD Actions"
{
    TableNo = "APD Session Hgd";

    trigger OnRun()
    begin
        Setup.GET();
        Setup.TESTFIELD("Serverpath ( /wsfn/ )");
        APDPath := Setup."Serverpath ( /wsfn/ )";

        // Commands (Codeunit called from <?codeunit('inline','parm1','parm2')?> tag
        CASE APD.GetParameter(Rec, 'PARAMETER1') OF
            'INLINE':
                begin
                    // Just returning the value of the second parameter as an example
                    APD.StreamWrite(APD.GetParameter(Rec, 'PARAMETER2'));
                end;
            '':
                // These are for Actions (Type Codeunit)
                CASE UPPERCASE(APD.GetParameter(Rec, 'ACTION')) OF
                    'ATTACHMENT.UPLOAD':
                        UploadAttachment(Rec);
                    'ATTACHMENT.UPLOADTO':
                        UploadAttachmentTo(Rec);
                    'ATTACHMENT.DOWNLOAD':
                        DownloadAttachment(Rec);
                    'NOTES.ADD':
                        AddNote(Rec);
                    'NOTES.EDIT':
                        EditNote(Rec);
                    ELSE
                        APD.HttpHeader(0, APDPath + '?_errormessage=Unknown action ' + APD.GetParameter(Rec, 'ACTION'), '', '', '')
                END;
        end;
    end;

    local procedure AddNote(var Session: Record "APD Session Hgd")
    var
        R: Codeunit "Record Link Management";
        RecordLink: Record "Record Link";
        SalesHeader: Record "Sales Header";
    begin
        if SalesHeader.Get(SalesHeader."Document Type"::Order, APD.GetParameter(Session, 'OrderNo')) then begin

            // There are no builtin validation on data in codeunits, so it's up to the developers
            // to make sure data is validated. In this case, a user could just pass a OrderNo parameter
            // for someones else's order. You must validate this yourself. In this case, we'll validate
            // that we can only add notes to sales order that have sell-to customer = the customer on the
            // APD user card.

            if Session."User Authenticated" and (Session."Navision number" = SalesHeader."Sell-to Customer No.") then begin
                RecordLink.Init();
                RecordLink.Insert(true);
                RecordLink.Created := APD.GetLocalDateTime();
                RecordLink.Company := CompanyName();
                RecordLink."User ID" := UserID();
                RecordLink."Record ID" := SalesHeader.RecordID;
                RecordLink.Type := RecordLink.Type::Note;
                R.WriteNote(RecordLink, APD.GetParameter(Session, 'Text'));
                RecordLink.Modify();
            end else
                error('Permission error, you do not have access to this sales order');
        end else
            error('Unknown Sales Order (%1)', APD.GetParameter(Session, 'OrderNo'));
    end;

    local procedure EditNote(var Session: Record "APD Session Hgd")
    var
        R: Codeunit "Record Link Management";
        RecordLink: Record "Record Link";
        SalesHeader: Record "Sales Header";
    begin
        if RecordLink.Get(APD.GetParameterInteger(Session, 'NoteID')) then begin
            if SalesHeader.Get(RecordLink."Record ID") then begin

                // There are no builtin validation on data in codeunits, so it's up to the developers
                // to make sure data is validated. In this case, a user could just pass a OrderNo parameter
                // for someones else's order. You must validate this yourself. In this case, we'll validate
                // that we can only edit notes on sales order that have sell-to customer = the customer on the
                // APD user card.

                if Session."User Authenticated" and (Session."Navision number" = SalesHeader."Sell-to Customer No.") then begin
                    R.WriteNote(RecordLink, APD.GetParameter(Session, 'Text'));
                    RecordLink.Modify();
                end else
                    error('Permission error, you do not have access to this sales order');
            end else
                error('Permission error, you do not have access to this sales order');
        end else
            error('Unknown Note (%1)', APD.GetParameter(Session, 'NoteID'));
    end;

    local procedure DownloadAttachment(var Session: Record "APD Session Hgd")
    var
        Document: Record "Document Attachment";
        SalesHeader: Record "Sales Header";
        OutS: OutStream;
        InS: InStream;
        TempBlob: Codeunit "Temp Blob";
    begin
        Document.Setrange("Table ID", DATABASE::"Sales Header");
        Document.Setrange("No.", APD.GetParameter(Session, 'OrderNo'));
        Document.Setrange("Document Type", Document."Document Type"::Order);
        Document.Setrange(ID, APD.GetParameterInteger(Session, 'DocID'));
        if Document.FindFirst() then begin
            if SalesHeader.Get(SalesHeader."Document Type"::Order, Document."No.") then begin

                // There are no builtin validation on data in codeunits, so it's up to the developers
                // to make sure data is validated. In this case, a user could just pass a OrderNo parameter
                // for someones else's order. You must validate this yourself. In this case, we'll validate
                // that we can download attachments to sales order that have sell-to customer = the customer on the
                // APD user card.

                if Session."User Authenticated" and (Session."Navision number" = SalesHeader."Sell-to Customer No.") then begin
                    TempBlob.CreateOutStream(OutS);
                    Document."Document Reference ID".ExportStream(OutS);
                    TempBlob.CreateInStream(InS);
                    APD.StreamBlob(InS, TempBlob.Length());
                    APD.HttpHeader(HttpHeader::"Raw File", 'application/octet-stream', 'attachment;filename=' + Document."File Name" + '.' + Document."File Extension", '', '');
                end else
                    error('Permission error, you do not have access to this document');
            end else
                error('Permission error, you do not have access to this document');

        end else
            error('Unknown Document');
    end;

    local procedure UploadAttachment(Session: Record "APD Session Hgd")
    var
        PH: Record "Purchase Header";
        Document: Record "Document Attachment";
        AttachMgt: Codeunit "Document Attachment Mgmt";
        InS: InStream;
        NameParts: List of [Text];
    begin
        // Purchase Order
        if PH.Get(PH."Document Type"::Order, APD.GetParameter(Session, '38:3')) then begin
            Session."Uploaded File".CreateInStream(InS);
            Document.Init();
            Document."Table ID" := DATABASE::"Purchase Header";
            Document."No." := PH."No.";
            Document."Document Type" := Document."Document Type"::Order;
            Document.ImportFromStream(InS, Session."Uploaded File Name");
            NameParts := Session."Uploaded File Name".Split('.');
            Document."File Name" := Session."Uploaded File Name".Substring(1, strlen(Session."Uploaded File Name") - 1 - strlen(NameParts.Get(NameParts.Count)));
            Document."File Extension" := NameParts.Get(NameParts.Count());
            Document.insert(true);
            APD.HttpHeader(0, APDPath + '?action=purchaseorder&38:1=1&38:3=' + PH."No.", '', '', '')
        end else
            error('Unkown order, cannot upload');
    end;

    local procedure UploadAttachmentTo(Session: Record "APD Session Hgd")
    var
        Document: Record "Document Attachment";
        InS: InStream;
        NameParts: List of [Text];
        TableID: Integer;
    begin
        // Unlike ATTACHMENT.UPLOAD (which is hardcoded to a Purchase Order), this
        // action lets the caller decide where the uploaded file is stored. The
        // destination record is identified through the parameters:
        //   TableID  - the table number to attach the file to (e.g. 36 = Sales Header)
        //   No       - the "No." of the record the file belongs to
        //   DocType  - (optional) Document Type ordinal, defaults to 0
        //   LineNo   - (optional) Line No., defaults to 0
        //
        // As with the other examples there is no built-in validation: a developer
        // MUST verify that the authenticated user is allowed to attach a file to
        // the requested record before inserting it. Here we only confirm that the
        // session is logged in - extend this with your own access checks.

        if not Session."User Authenticated" then
            error('Permission error, you must be logged in to upload attachments');

        TableID := APD.GetParameterInteger(Session, 'TableID');
        if TableID = 0 then
            error('Missing or invalid TableID parameter');

        if Session."Uploaded File Name" = '' then
            error('No file was uploaded');

        Session."Uploaded File".CreateInStream(InS);
        Document.Init();
        Document."Table ID" := TableID;
        Document."No." := CopyStr(APD.GetParameter(Session, 'No'), 1, MaxStrLen(Document."No."));
        Document."Document Type" := Enum::"Attachment Document Type".FromInteger(APD.GetParameterInteger(Session, 'DocType'));
        Document."Line No." := APD.GetParameterInteger(Session, 'LineNo');
        Document.ImportFromStream(InS, Session."Uploaded File Name");
        NameParts := Session."Uploaded File Name".Split('.');
        Document."File Name" := CopyStr(Session."Uploaded File Name".Substring(1, StrLen(Session."Uploaded File Name") - 1 - StrLen(NameParts.Get(NameParts.Count))), 1, MaxStrLen(Document."File Name"));
        Document."File Extension" := CopyStr(NameParts.Get(NameParts.Count()), 1, MaxStrLen(Document."File Extension"));
        Document.Insert(true);

        APD.HttpHeader(0, APDPath + '?_message=Attachment uploaded', '', '', '')
    end;

    var
        Setup: Record "APD Setup Hgd";
        APD: Codeunit "APD Worker Hgd";
        APDPath: Text[250];
        HttpHeader: Option Redirect,"Raw File","PDF Convertion","File Redirect";
}