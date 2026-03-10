# Global Vendors

## What this feature is
Global Vendors are shared vendor records managed once at account level and reused across events.

## Where to manage global vendors
- Left sidebar (index/admin shell): **Vendors**.
- Route: Settings-level global vendor list.

## What you can manage in a global vendor record
- Vendor name
- Default vendor type
- Default social handle
- Contact list (name/title/email/phone/notes)

## Where global vendors are used
Inside each event under **Event Info → Vendors**:
- Vendor name inputs support lookup/selection from global vendor records.
- Linking to a global vendor can prefill defaults and standardize naming.

## Safe-delete rule
A global vendor cannot be deleted while linked to one or more event vendor records.

## How an operator should use it
1. Maintain canonical vendor records globally.
2. In each event, select the matching global vendor rather than retyping from scratch.
3. Keep event-specific visibility and ordering in the event-level Vendors page.
