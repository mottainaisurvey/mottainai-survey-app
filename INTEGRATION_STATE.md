> **Instructions for Agents**: This document is the single source of truth for the integration between the mobile app and the backend. Both agents **MUST** read this file at the start of each session and update it at the end of each session to reflect any changes that affect the other agent.

# Integration State & API Contract

**Last Updated**: November 24, 2025

---

## 1. System Status

| Component | Version | Last Updated | Key Details |
| :--- | :--- | :--- | :--- |
| 📱 **Mobile App** | `v3.0.0` | Nov 24, 2025 | APK: `mottainai-survey-app-v3.0.0-all-fixes.apk` |
| ☁️ **Backend** | *[Backend agent to fill]* | *[Backend agent to fill]* | API URL: `http://172.232.24.180:3003` |
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
- `wheelieBinType`, `incidentReport`, `companyId`, and `companyName` are optional and may be `null`.

#### Backend Response (What the app expects)

- **On Success**: The mobile app expects a `200 OK` or `201 Created` status code with a simple JSON response confirming success, e.g., `{"status": "success", "message": "Pickup recorded"}`.
- **On Failure**: The app expects a non-2xx status code with a JSON response containing an error message, e.g., `{"status": "error", "message": "Invalid data provided"}`.

---

## 3. Known Integration Issues & Pending Changes

This section tracks active issues and planned changes that may impact either system.

### Current Issues

1.  **Zoho Sync Failure**: Pickups submitted from the mobile app are not appearing in Zoho. The backend agent needs to investigate the Zoho integration logic.
2.  **Missing Data in Admin**: The admin panel is not displaying the `amount` and `pickup date` for new pickups. The backend agent needs to check the `/forms/submit` endpoint and the database schema.
3.  **Missing Pickup Details Card**: The admin panel needs a feature to show a detailed pickup card when a record is clicked. The backend agent needs to create a new API endpoint and update the admin UI.

### Pending Changes

- **📱 Mobile App**: No pending changes. Awaiting backend fixes for the issues listed above.
- **☁️ Backend**: *[Backend agent to document any planned changes here, e.g., "Adding new field 'isPriority' to pickup form"]*.

---

## 4. Change Log

| Date | System | Agent | Change Description |
| :--- | :--- | :--- | :--- |
| Nov 24, 2025 | Mobile | Manus | **v3.0.0 Release**: Fixed zoom level, tap behavior, placeholder text, and read-only date field. |
| | | | |
