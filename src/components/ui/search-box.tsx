/** SearchBox — pill input with a gold magnifier and a clear «✕» button (website SearchBox). */
import Ionicons from "@expo/vector-icons/Ionicons";
import { useState } from "react";
import { Pressable, TextInput, View, type StyleProp, type ViewStyle } from "react-native";

import { RADIUS, SPACE, TOUCH_MIN, TYPE, fontFamily, useTheme } from "@/theme";

import { AppText, TEXT_START } from "./app-text";

export interface SearchBoxProps {
  value: string;
  onChangeText: (text: string) => void;
  placeholder?: string;
  onSubmit?: (text: string) => void;
  autoFocus?: boolean;
  accessibilityLabel?: string;
  style?: StyleProp<ViewStyle>;
}

export function SearchBox({ value, onChangeText, placeholder = "ابحث…", onSubmit, autoFocus, accessibilityLabel, style }: SearchBoxProps) {
  const { colors, textScale } = useTheme();
  const [focused, setFocused] = useState(false);
  return (
    <View
      style={[
        {
          flexDirection: "row",
          alignItems: "center",
          gap: SPACE.sm,
          minHeight: TOUCH_MIN + 4,
          paddingHorizontal: SPACE.lg,
          borderRadius: RADIUS.pill,
          borderWidth: 1,
          borderColor: focused ? colors.gold : colors.line,
          backgroundColor: colors.surface,
        },
        style,
      ]}
    >
      <Ionicons name="search" size={18} color={colors.gold} />
      <TextInput
        value={value}
        onChangeText={onChangeText}
        onSubmitEditing={onSubmit ? (e) => onSubmit(e.nativeEvent.text) : undefined}
        placeholder={placeholder}
        placeholderTextColor={colors.muted}
        autoFocus={autoFocus}
        autoCorrect={false}
        autoCapitalize="none"
        returnKeyType="search"
        accessibilityLabel={accessibilityLabel ?? placeholder}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        selectionColor={colors.gold}
        style={{
          flex: 1,
          minHeight: TOUCH_MIN,
          paddingVertical: SPACE.sm,
          color: colors.text,
          fontFamily: fontFamily("body"),
          fontSize: TYPE.body.size * textScale,
          textAlign: TEXT_START,
          writingDirection: "rtl",
        }}
      />
      {value ? (
        <Pressable onPress={() => onChangeText("")} accessibilityRole="button" accessibilityLabel="مسح البحث" hitSlop={10}>
          <AppText color="muted">✕</AppText>
        </Pressable>
      ) : null}
    </View>
  );
}
