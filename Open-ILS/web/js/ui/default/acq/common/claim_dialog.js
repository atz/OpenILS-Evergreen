function ClaimDialogManager(dialog, finalDialog, eligibleLidByLi) {
    var self = this;

    this.anyLids = false;
    this.anyEligible = false;
    this.showingLidNodes = {};

    this.dialog = dialog;
    this.finalDialog = finalDialog;
    this.eligibleLidByLi = eligibleLidByLi;

    this.showingList = dojo.byId("acq-lit-li-claim-dia-lid-list");
    this.eligibleList = dojo.byId("acq-lit-li-claim-dia-lid-list-init");

    this.showingLidTemplate = this.showingList.removeChild(
        nodeByName("lid", this.showingList)
    );
    this.showingClaimTemplate =
        nodeByName("claims", this.showingLidTemplate).removeChild(
            nodeByName("claim", this.showingLidTemplate)
        );
    this.eligibleTemplate = this.eligibleList.removeChild(
        nodeByName("lid_to_claim", this.eligibleList)
    );

    dojo.byId("acq-lit-li-claim-dia-claim").onclick = function() {
        var lid_ids = self.getSelectedEligible();
        if (lid_ids.length) {
            dojo.byId("acq-eligible-claim-submit").onclick = function() {
                self.finalDialog.hide();
                self.claim(lid_ids);
            };
            self.dialog.hide();
            self.finalDialog.show();
        }
        else {
            alert(localeStrings.NO_LID_TO_CLAIM);
        }
    };

    new openils.widget.AutoFieldWidget({
        "fmClass": "acqclt",
        "selfReference": true,
        "dijitArgs": {"required": true},
        "parentNode": dojo.byId("acq-eligible-claim-type")
    }).build(function(w) { self.claimType = w; });

    this.reset = function(li) {
        this.anyLids = false;
        this.showingLidNodes = {};

        openils.Util.hide("acq-lit-li-claim-dia-initiate");
        openils.Util.hide("acq-lit-li-claim-dia-show");

        dojo.empty(this.showingList);
        dojo.empty(this.eligibleList);
    };

    this.show = function(li) {
        this.reset();
        this.prepare(li);
        this.dialog.show();
    };

    this.hide = function() { this.dialog.hide(); };

    this.prepare = function(li) {
        dojo.byId("acq-lit-li-claim-dia-li-title").innerHTML =
            li.attributes().filter(
                function(o) { return Boolean(o.attr_name() == "title"); }
            )[0].attr_value();
        dojo.byId("acq-lit-li-claim-dia-li-id").innerHTML = li.id();

        li.lineitem_details().forEach(
            function(lid) {
                lid.claims().forEach(
                    function(claim) { self.addClaim(lid, claim); }
                );
                if (self.eligibleLidByLi[li.id()].indexOf(lid.id()) != -1) {
                    self.addEligible(lid);
                }
            }
        );
    };

    this._reprReceived = function(lid) {
        if (lid.cancel_reason())
            return localeStrings.CANCELED + ": " + lid.cancel_reason().label();
        else if (lid.recv_time())
            return localeStrings.RECVD + " " + lid.recv_time();
        else
            return localeStrings.NOT_RECVD;
    };

    this.addClaim = function(lid, claim) {
        if (!this.anyLids)
            openils.Util.show("acq-lit-li-claim-dia-show");
        this.anyLids = true;

        var lidNode = this.showingLidNodes[lid.id()];
        if (!lidNode) {
            lidNode = dojo.clone(this.showingLidTemplate);
            nodeByName("barcode", lidNode).innerHTML = lid.barcode();
            nodeByName("recvd", lidNode).innerHTML = this._reprReceived(lid);

            this.showingLidNodes[lid.id()] = lidNode;
            dojo.place(lidNode, this.showingList, "last");
        }

        var claimNode = dojo.clone(this.showingClaimTemplate);
        nodeByName("type", claimNode).innerHTML = claim.type().code();
        nodeByName("voucher", claimNode).onclick = function() {
            alert("unimplemented"); // XXX
            // TODO For some reason, the format.acqcle.html events that get
            // fired by claim_item() in Claims.pm don't stick around in
            // the database.  Must find out why and fix this before writing
            // the ML method that the following code would call.
            /*
            var win;
            fieldmapper.standardRequest(
                ["open-ils.acq", "open-ils.acq.claim.get_format_events"], {
                    "params": [openils.User.authtoken, lid.id()],
                    "async": true,
                    "onresponse": function(r) {
                        if (r = openils.Util.readResponse(r)) {
                            if (!win)
                                win = openClaimVoucherWindow();
                        }
                        dojo.byId("main", win.document).innerHTML +=
                            (contents + "<hr />");
                    },
                    "oncomplete": function() {
                        var print_button = dojo.byId("print", win.document);
                        print_button.innerHTML = localeStrings.PRINT;
                        print_button.disabled = false;
                    }
                }
            );
            */
        };

        dojo.place(
            claimNode, nodeByName("claims", lidNode), "last"
        );
    };

    this.addEligible = function(lid) {
        if (!this.anyEligible)
            openils.Util.show("acq-lit-li-claim-dia-initiate");
        this.anyEligible = true;

        var eligibleNode = dojo.clone(this.eligibleTemplate);
        nodeByName("claimable_lid", eligibleNode).value = lid.id();
        dojo.attr(
            nodeByName("claimable_lid", eligibleNode),
            "id", "claim-lid-" + lid.id()
        );
        dojo.attr(
            nodeByName("claimable_lid_label", eligibleNode),
            "for", "claim-lid-" + lid.id()
        );
        nodeByName("barcode", eligibleNode).innerHTML = lid.barcode();
        nodeByName("recvd", eligibleNode).innerHTML = this._reprReceived(lid);

        dojo.place(eligibleNode, this.eligibleList, "last");
    };

    this.getSelectedEligible = function() {
        return dojo.query("input[name='claimable_lid']", this.eligibleList).
            filter(function(o) { return o.checked; }).
            map(function(o) { return o.value; });
    };

    this.claim = function(lid_ids) {
        progressDialog.show(true);
        var win = null;

        fieldmapper.standardRequest(
            ["open-ils.acq", "open-ils.acq.claim.lineitem_detail"], {
                "params": [
                    openils.User.authtoken, lid_ids, null,
                    this.claimType.attr("value"),
                    dijit.byId("acq-eligible-claim-note").attr("value")
                ],
                "async": true,
                "onresponse": function(r) {
                    if (r = openils.Util.readResponse(r)) {
                        if (!win)
                            win = openClaimVoucherWindow();
                        dojo.byId("main", win.document).innerHTML +=
                            (r.template_output().data() + "<hr />");
                    }
                    else {
                        progressDialog.hide();
                    }
                },
                "oncomplete": function() {
                    progressDialog.hide();
                    dojo.byId("print", win.document).innerHTML =
                        localeStrings.PRINT;
                    dojo.byId("print", win.document).disabled = false;
                }
            }
        );
    };
}