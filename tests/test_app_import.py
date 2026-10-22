
from unittest import mock


def test_app_import_success() -> None:
    """Smoke test to ensure the Streamlit app and V3/V4 UI modules import without errors."""
    import ai_search_journey.app

    assert ai_search_journey.app is not None


def test_quick_demo_presets() -> None:
    """Verify quick demo presets are accurately defined and include the UH and Baltimore presets."""
    from ai_search_journey.app import (
        DEFAULT_BALTIMORE_PRIMARY_CARE_QUERY,
        DEFAULT_BALTIMORE_QUERY,
        DEFAULT_COFFEE_QUERY,
        DEFAULT_DENTIST_QUERY,
        DEFAULT_INDIAN_QUERY,
        DEFAULT_PRIMARY_CARE_QUERY,
        DEFAULT_XAVIER_QUERY,
    )

    assert "Geekdom San Antonio" in DEFAULT_COFFEE_QUERY
    assert "Trinity University" in DEFAULT_INDIAN_QUERY
    assert (
        DEFAULT_DENTIST_QUERY
        == "Find three pediatric dentists near the University of Houston "
        "for a child anxious about dental visits."
    )
    assert "Xavier University of Louisiana" in DEFAULT_XAVIER_QUERY
    expected_baltimore_query = (
        "Find three primary care practices near Johns Hopkins Hospital in Baltimore "
        "that are open around noon. Compare distance, ratings, reviews, services, and hours, "
        "then explain why you selected each one with citations."
    )
    assert DEFAULT_BALTIMORE_QUERY == expected_baltimore_query
    assert DEFAULT_PRIMARY_CARE_QUERY == expected_baltimore_query
    assert DEFAULT_BALTIMORE_PRIMARY_CARE_QUERY == expected_baltimore_query


def test_render_app_preset_selection() -> None:
    """Verify selecting presets in render_app passes expected queries to user_question."""
    from ai_search_journey.app import (
        DEFAULT_BALTIMORE_QUERY,
        DEFAULT_COFFEE_QUERY,
        DEFAULT_DENTIST_QUERY,
        DEFAULT_INDIAN_QUERY,
        DEFAULT_XAVIER_QUERY,
        render_app,
    )

    expected_mappings = {
        "Coffee Shop @ Geekdom": DEFAULT_COFFEE_QUERY,
        "Indian Restaurant @ Trinity": DEFAULT_INDIAN_QUERY,
        "Pediatric Dentist @ UH": DEFAULT_DENTIST_QUERY,
        "Cajun / Crawfish @ Xavier": DEFAULT_XAVIER_QUERY,
        "Primary Care @ Johns Hopkins Baltimore": DEFAULT_BALTIMORE_QUERY,
        "Custom": "",
    }

    def mock_columns_side_effect(spec, *args, **kwargs):
        count = spec if isinstance(spec, int) else len(spec)
        return [mock.MagicMock() for _ in range(count)]

    for preset_label, expected_query in expected_mappings.items():
        mock_session_state = mock.MagicMock()

        def mock_selectbox_side_effect(label, *args, target=preset_label, **kwargs):
            if label == "Quick Demo Presets":
                return target
            options = kwargs.get("options", [])
            if isinstance(options, range) and len(options) > 0:
                return 0
            return options[0] if len(options) > 0 else None

        with (
            mock.patch("streamlit.set_page_config"),
            mock.patch("streamlit.columns", side_effect=mock_columns_side_effect),
            mock.patch(
                "streamlit.selectbox", side_effect=mock_selectbox_side_effect
            ) as mock_selectbox,
            mock.patch("streamlit.text_area") as mock_text_area,
            mock.patch("streamlit.button", return_value=False),
            mock.patch("streamlit.session_state", mock_session_state),
            mock.patch("ai_search_journey.app.render_header_logos"),
            mock.patch("ai_search_journey.app.render_app_title"),
            mock.patch("ai_search_journey.app.init_telemetry"),
        ):
            render_app()

            # Verify selectbox received the correct options
            preset_calls = [
                c
                for c in mock_selectbox.call_args_list
                if c.args and c.args[0] == "Quick Demo Presets"
            ]
            assert len(preset_calls) == 1
            _, kwargs = preset_calls[0]
            assert kwargs["options"] == [
                "Coffee Shop @ Geekdom",
                "Indian Restaurant @ Trinity",
                "Pediatric Dentist @ UH",
                "Cajun / Crawfish @ Xavier",
                "Primary Care @ Johns Hopkins Baltimore",
                "Custom",
            ]
            assert kwargs["index"] == 0

            # Verify text_area received expected default query
            mock_text_area.assert_called_once()
            _, text_kwargs = mock_text_area.call_args
            assert text_kwargs["value"] == expected_query
