import FontAwesome from '@expo/vector-icons/FontAwesome';
import clsx from 'clsx';
import { Link, Tabs } from 'expo-router';
import { Pressable, Text, View } from 'react-native';
import { useRecoilState, useRecoilValue } from 'recoil';
import i18n from '../../assets/locales';
import { Platform } from 'react-native';
import {
  defaultDesiredSize,
  imagesState,
  settingsState
} from '../../lib/state';

/**
 * You can explore the built-in icon families and icons on the web at https://icons.expo.fyi/
 */
function TabBarIcon(props: {
  name: React.ComponentProps<typeof FontAwesome>['name'];
  color: string;
  isDisabled?: boolean;
}) {
  return (
    <Pressable disabled={props.isDisabled}>
      <FontAwesome
        size={20}
        style={{ opacity: props.isDisabled ? 0.25 : 1, marginBottom: -3 }}
        {...props}
      />
    </Pressable>
  );
}

function TabBarLabel(props: { text: string; isDisabled?: boolean }) {
  return (
    <Text
      className={clsx(
        'text-xs font-space',
        { 'mb-2': Platform.OS === 'android' },
        {
          'text-zinc-800': props.isDisabled,
          'text-zinc-200': !props.isDisabled
        }
      )}
    >
      {props.text}
    </Text>
  );
}

export default function TabLayout() {
  const [settings, setSettings] = useRecoilState(settingsState);
  const images = useRecoilValue(imagesState);
  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: 'white',
        tabBarInactiveTintColor: 'gray',
        tabBarStyle: {
          height: Platform.OS === 'ios' ? '10%' : '8.3%',
          borderTopWidth: 1,
          shadowColor: 'transparent',
          elevation: 0
        }
      }}
    >
      <Tabs.Screen
        name="index"
        listeners={{
          tabPress: (e) => {
            setSettings((settings) => ({
              ...settings,
              desiredSize: defaultDesiredSize
            }));
          }
        }}
        options={{
          headerShown: false,
          title: images.length === 0 ? i18n.t('select') : i18n.t('preview'),
          tabBarLabel: ({ focused }) => (
            <TabBarLabel
              text={images.length === 0 ? i18n.t('select') : i18n.t('preview')}
            />
          ),
          tabBarIcon: ({ color }) => <TabBarIcon name="photo" color={color} />
        }}
      />
      <Tabs.Screen
        name="edit"
        listeners={{
          tabPress: (e) => {
            // Prevent default action
            if (images.length === 0) {
              e.preventDefault();
            }
            setSettings((settings) => ({
              ...settings,
              desiredSize: 320
            }));
          }
        }}
        options={{
          headerShown: false,
          title: i18n.t('edit'),
          tabBarLabel: ({ focused }) => (
            <TabBarLabel
              text={i18n.t('edit')}
              isDisabled={images.length === 0}
            />
          ),
          tabBarIcon: ({ color }) => (
            <TabBarIcon
              name="pencil"
              color={color}
              isDisabled={images.length === 0}
            />
          )
        }}
      />
      <Tabs.Screen
        name="export"
        listeners={{
          tabPress: (e) => {
            // Prevent default action
            if (images.length === 0) e.preventDefault();
          }
        }}
        options={{
          headerShown: false,
          title: i18n.t('export'),
          tabBarLabel: ({ focused }) => (
            <TabBarLabel
              text={i18n.t('export')}
              isDisabled={images.length === 0}
            />
          ),
          tabBarIcon: ({ color }) => (
            <TabBarIcon
              name="share"
              color={color}
              isDisabled={images.length === 0}
            />
          ),
          headerRight: () => (
            <Link href="/modal" asChild>
              <Pressable>
                {({ pressed }) => (
                  <FontAwesome
                    name="info-circle"
                    size={24}
                    style={{
                      color: 'white',
                      marginRight: 15,
                      opacity: pressed ? 0.5 : 1
                    }}
                  />
                )}
              </Pressable>
            </Link>
          )
        }}
      />
    </Tabs>
  );
}

export function PageContainer({ children }: { children: React.ReactNode }) {
  return (
    <View className="bg-zinc-900 relative flex-1 flex-col items-center justify-center p-2 mt-10">
      {children}
    </View>
  );
}
