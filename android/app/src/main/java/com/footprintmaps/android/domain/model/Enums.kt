package com.footprintmaps.android.domain.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class RegionType(val value: String) {
    @SerialName("country") COUNTRY("country"),
    @SerialName("us_state") US_STATE("us_state"),
    @SerialName("canadian_province") CANADIAN_PROVINCE("canadian_province"),
    @SerialName("australian_state") AUSTRALIAN_STATE("australian_state"),
    @SerialName("mexican_state") MEXICAN_STATE("mexican_state"),
    @SerialName("brazilian_state") BRAZILIAN_STATE("brazilian_state"),
    @SerialName("german_state") GERMAN_STATE("german_state"),
    @SerialName("french_region") FRENCH_REGION("french_region"),
    @SerialName("spanish_community") SPANISH_COMMUNITY("spanish_community"),
    @SerialName("italian_region") ITALIAN_REGION("italian_region"),
    @SerialName("dutch_province") DUTCH_PROVINCE("dutch_province"),
    @SerialName("belgian_province") BELGIAN_PROVINCE("belgian_province"),
    @SerialName("uk_country") UK_COUNTRY("uk_country"),
    @SerialName("russian_federal_subject") RUSSIAN_FEDERAL_SUBJECT("russian_federal_subject"),
    @SerialName("argentine_province") ARGENTINE_PROVINCE("argentine_province");

    companion object {
        fun fromValue(value: String): RegionType? =
            entries.find { it.value == value }
    }
}

@Serializable
enum class PlaceStatus(val value: String) {
    @SerialName("visited") VISITED("visited"),
    @SerialName("bucket_list") BUCKET_LIST("bucket_list");

    companion object {
        fun fromValue(value: String): PlaceStatus? =
            entries.find { it.value == value }
    }
}

@Serializable
enum class VisitType(val value: String) {
    @SerialName("visited") VISITED("visited"),
    @SerialName("transit") TRANSIT("transit");

    companion object {
        fun fromValue(value: String): VisitType? =
            entries.find { it.value == value }
    }
}

enum class Continent(val displayName: String) {
    EUROPE("Europe"),
    ASIA("Asia"),
    NORTH_AMERICA("North America"),
    SOUTH_AMERICA("South America"),
    AFRICA("Africa"),
    OCEANIA("Oceania"),
    ANTARCTICA("Antarctica")
}
