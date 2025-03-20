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

    var
        Setup: Record "APD Setup Hgd";
        APD: Codeunit "APD Worker Hgd";
        APDPath: Text[250];
        HttpHeader: Option Redirect,"Raw File","PDF Convertion","File Redirect";
}