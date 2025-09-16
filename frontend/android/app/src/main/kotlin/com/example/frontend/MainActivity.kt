package com.example.frontend

import android.content.ContentResolver
import android.database.Cursor
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.example.frontend/contacts"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        setupContactChannel(flutterEngine)
    }

    private fun setupContactChannel(flutterEngine: FlutterEngine) {
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getContacts" -> {
                    try {
                        val contacts = getContacts()
                        result.success(contacts)
                    } catch (e: Exception) {
                        result.error("CONTACT_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getContacts(): String {
        val contacts = JSONArray()
        var cursor: Cursor? = null

        try {
            val contentResolver: ContentResolver = this.contentResolver
            cursor = contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                null,
                null,
                null,
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
            )

            if (cursor != null && cursor.count > 0) {
                val nameIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val phoneIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                
                // Use getColumnIndexOrThrow for better error handling
                val displayNameIndex = try {
                    cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                } catch (e: Exception) {
                    -1
                }
                
                val phoneNumberIndex = try {
                    cursor.getColumnIndexOrThrow(ContactsContract.CommonDataKinds.Phone.NUMBER)
                } catch (e: Exception) {
                    -1
                }

                while (cursor.moveToNext()) {
                    try {
                        val name = if (displayNameIndex >= 0) {
                            cursor.getString(displayNameIndex) ?: ""
                        } else {
                            ""
                        }
                        
                        val phone = if (phoneNumberIndex >= 0) {
                            cursor.getString(phoneNumberIndex) ?: ""
                        } else {
                            ""
                        }

                        // Only add contacts that have both name and phone
                        if (name.isNotEmpty() && phone.isNotEmpty()) {
                            val contact = JSONObject()
                            contact.put("name", name)
                            contact.put("phone", phone)
                            contacts.put(contact)
                        }
                    } catch (e: Exception) {
                        // Skip this contact if there's an error reading it
                        continue
                    }
                }
            }
        } catch (e: Exception) {
            // Handle any exceptions
            e.printStackTrace()
            return "[]" // Return empty array on error
        } finally {
            cursor?.close()
        }

        return contacts.toString()
    }
}