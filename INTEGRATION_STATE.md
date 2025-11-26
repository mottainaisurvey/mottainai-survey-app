> **Instructions for Agents**: This document is the single source of truth for the integration between the mobile app and the backend. Both agents **MUST** read this file at the start of each session and update it at the end of each session to reflect any changes that affect the other agent.

# Integration State & API Contract

**Last Updated**: November 24, 2025

---

## 1. System Status

| Component | Version | Last Updated | Key Details |
| :--- | :--- | :--- | :--- |
| 📱 **Mobile App** | `v3.1.1` | Nov 25, 2025 | APK: `mottainai-survey-app-v3.1.1.apk` |
| ☁️ **Backend** | `v2.2.0` | Nov 25, 2025 | API URL: `https://upwork.kowope.xyz` |
| 🗃️ **Database** | `v6` (SQLite) | Nov 24, 2025 | `customerLabels` column added to `cached_polygons` |

---

## 2. API Contract

This section defines the API contract between the mobile app and the backend. The mobile app relies on these endpoints and data structures.

### `POST /forms/submit`

This endpoint is used to submit a new pickup record from the mobile app.

#### Mobile App Payload (What the app sends)

The mobile app sends a JSON object with the following structure and data types:

```json
{
  "customerName": "string",
  "customerPhone": "string",
  "customerEmail": "string",
  "customerAddress": "string",
  "customerType": "string",
  "binType": "string",
  "wheelieBinType": "string?",
  "binQuantity": "int",
  "buildingId": "string",
  "pickUpDate": "string",
  "firstPhoto": "string",
  "secondPhoto": "string",
  "incidentReport": "string?",
  "userId": "int",
  "latitude": "double",
  "longitude": "double",
  "createdAt": "string",
  "companyId": "string?",
  "companyName": "string?"
}
```

**Key Field Details**:
- `pickUpDate` is sent in the format: `'MMM dd, yyyy'` (e.g., "Nov 24, 2025").
- `createdAt` is sent in ISO 8601 format.
- `socioClass` is required for residential customers (values: "low", "medium", "high").
- `wheelieBinType`, `incidentReport`, `companyId`, `companyName`, and `socioClass` (for commercial) are optional and may be `null`.
- Photos are sent as multipart/form-data files, not as paths.
- Backend calculates pricing automatically - mobile app does NOT send price/amount.

#### Backend Response (What the app expects)

- **On Success**: The mobile app expects a `200 OK` or `201 Created` status code with a simple JSON response confirming success, e.g., `{"status": "success", "message": "Pickup recorded"}`.
- **On Failure**: The app expects a non-2xx status code with a JSON response containing an error message, e.g., `{"status": "error", "message": "Invalid data provided"}`.

---

## 3. Known Integration Issues & Pending Changes

This section tracks active issues and planned changes that may impact either system.

### Current Issues

**✅ All backend issues resolved as of Nov 25, 2025!**

1.  ✅ **Zoho Sync** - Working with auto-refresh
2.  ✅ **S3 Photo Storage** - Configured (AWS eu-west-1, bucket: mottainai-photos)
3.  ✅ **Price Calculation** - Server-side with all 9 pricing tiers
4.  ✅ **Pickup Details API** - `GET /api/pickups/:id` endpoint available

### Pending Changes

- **📱 Mobile App**: Need to add customer contact fields (customerName, customerPhone, customerEmail, customerAddress) to the pickup form.
- **☁️ Backend**: No pending changes. All systems operational.

### Recently Fixed

- **✅ companyId in Submissions** (v3.1.1): Mobile app now sends user's companyId with every pickup submission, enabling the Company filter in admin dashboard.

---

## 4. Change Log

| Date | System | Agent | Change Description |
| :--- | :--- | :--- | :--- |
| Nov 25, 2025 | Backend | Backend Agent | **v2.2.0 Release**: Zoho integration, S3 photo storage, server-side pricing, pickup details API |
| Nov 25, 2025 | Mobile | Manus | **v3.1.1 Release**: Fixed companyId submission (uses user's companyId), enables Company filter in admin dashboard |
| Nov 25, 2025 | Mobile | Manus | **v3.1.0 Release**: Updated API URL to https://upwork.kowope.xyz, added socioClass field for residential customers, photo upload via multipart/form-data, removed loading blocker |
| Nov 24, 2025 | Mobile | Manus | **v3.0.0 Release**: Fixed zoom level, tap behavior, placeholder text, and read-only date field |
