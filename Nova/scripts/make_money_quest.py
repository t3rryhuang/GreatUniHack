#!/usr/bin/env python3
"""Writes Nova/Nova/Resources/MoneyQuest/chapters.json.

Non-coders can also edit chapters.json directly. Facts that can change or must be
accurate live ONLY in the "facts" list (with verifyBeforeDemo and year); level
text refers to them as {{fact:id}}. Chapters with "needsMoreContent": true have a
single level and need more writing before launch.
"""
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "Nova" / "Resources" / "MoneyQuest" / "chapters.json"

FACTS = [
    ("niNumber", "Most young people get their National Insurance number by letter shortly before they turn 16.", "HMRC / gov.uk"),
    ("personalAllowance", "Most people can earn some money each tax year before paying Income Tax (the Personal Allowance). Check gov.uk for this year's amount.", "gov.uk"),
    ("taxCode", "Your tax code tells your employer how much tax-free pay you get. If it looks wrong, contact HMRC.", "gov.uk"),
    ("creditFileAge", "You usually can't take out credit until you're 18, so most credit files start around then.", "Credit reference agencies"),
    ("electoralRegister", "Lenders use the electoral register to confirm who you are and where you live. The age you can register and vote differs across the UK nations, so check gov.uk/register-to-vote.", "gov.uk"),
    ("missedPayments", "Missed payments usually stay on a credit file for six years.", "Credit reference agencies"),
    ("paydayCap", "In the UK the total interest and fees on a payday loan are capped at the amount you borrowed, but they're still a very expensive way to borrow.", "FCA"),
    ("bnplCredit", "Buy now pay later is borrowing. Missing payments can mean late fees and, with some providers, a mark on your credit file.", "FCA / MoneyHelper"),
    ("fraudLine", "If you think a call or message about your bank is a scam, hang up and call 159 to reach your bank safely. Not every bank uses 159, so you can also use the number on the back of your card.", "Stop Scams UK"),
    ("reportFraud", "Report fraud to your bank straight away, then to the police's fraud reporting service for your part of the UK.", "Police / gov.uk"),
    ("moneyMule", "Letting someone move money through your account is money muling. It's a crime, even if you're told it's a 'job', and it can get your bank account closed.", "UK Finance / police"),
    ("phoneContract", "A phone contract with a handset is usually a credit agreement, so missed payments can show on your credit file.", "Credit reference agencies"),
    ("depositProtection", "In England and Wales, landlords must protect a tenancy deposit in a government-approved scheme. Rules differ in Scotland and Northern Ireland.", "gov.uk"),
    ("councilTax", "Some people get a council tax discount or don't pay it at all, for example if everyone in the home is a full-time student.", "gov.uk"),
    ("socialTariffs", "Many broadband and mobile companies offer cheaper 'social tariffs' to people on certain benefits.", "Ofcom"),
    ("debtAdvice", "Free, confidential debt advice is available from charities such as Citizens Advice, StepChange and National Debtline, and from MoneyHelper.", "MoneyHelper"),
    ("benefitsCheck", "Free online benefits calculators can show what support you might be able to get.", "gov.uk"),
    ("savingsProtection", "Savings in UK banks are protected by the Financial Services Compensation Scheme (FSCS) up to a limit per person, per bank.", "FSCS"),
]


def ev(prompt, *options, topic=None):
    return {"kind": "event", "prompt": prompt, "topic": topic, "options": [o for o in options]}


def q(prompt, *options, topic=None):
    return {"kind": "question", "prompt": prompt, "topic": topic, "options": [o for o in options]}


def opt(text, explanation, correct=None, **effects):
    o = {"text": text, "explanation": explanation, "effects": effects}
    if correct is not None:
        o["correct"] = correct
    return o


def tf(prompt, answer, explanation, topic=None):
    return q(prompt,
             opt("True", explanation, correct=answer is True),
             opt("False", explanation, correct=answer is False), topic=topic)


CHAPTERS = [
    {
        "id": 1, "title": "Needs, wants and your first budget", "symbol": "list.bullet.clipboard.fill",
        "summary": "Tell needs from wants and make a plan for payday.", "needsMoreContent": False,
        "levels": [
            {"title": "Payday plan", "persona": "Aisha, 17, works in a café. Her hours change every week.",
             "steps": [
                 ev("Payday! Your shifts were short this month, so you've been paid less than usual. What do you do first?",
                    opt("List my needs first: bus fares, my phone share and food at college", "Covering needs first means a short month doesn't turn into missed bills.", balance=15, wisdom=10, money=0),
                    opt("Spend as normal and hope next month is better", "When income goes up and down, planning for the low months protects you.", balance=-15, resilience=-10, money=-40),
                    opt("Put a little aside first, even £5", "Saving a small amount first builds the habit, whatever you earn.", resilience=15, endurance=5, money=-5),
                    topic="budgeting with irregular income"),
                 q("Which of these is a need?",
                   opt("A bus pass to get to college", "Getting to college or work is a need. The others are wants: nice, but you can live without them.", correct=True),
                   opt("New trainers when yours are fine", "Trainers that still work are a want right now. A need is something you can't do without.", correct=False),
                   opt("A second streaming subscription", "Streaming is a want. It's fine to have wants, just after needs.", correct=False),
                   opt("A takeaway on Friday", "A takeaway is a want. Food is a need, but takeaways cost more.", correct=False),
                   topic="needs and wants"),
                 ev("A friend's birthday meal costs £25, but you planned £15 for fun this month.",
                    opt("Suggest a cheaper plan, or just go for dessert", "Being honest about your budget is a skill, and friends usually get it.", wisdom=10, balance=10, money=-10),
                    opt("Go and pay £25 anyway", "That's OK sometimes, but it means cutting something else this month.", balance=-10, money=-25),
                    opt("Skip it and send a card", "Also fine. The point is deciding with your budget, not on the spot.", balance=5, money=-2),
                    topic="saying no to spending"),
                 tf("A budget is only useful if you have lots of money.", False,
                    "False. A budget matters most when money is tight. It's just a plan for the money you have.", topic="budgeting"),
             ],
             "learned": ["Cover needs before wants.", "Plan for your lowest-paid months, not your best.", "Saving a little first works on any income."]},
            {"title": "Sharing a flat", "persona": "Ollie, 17, lives with his older sister and pays towards food.",
             "steps": [
                 ev("Your sister asks you to put £20 a week towards food shopping. How do you plan for it?",
                    opt("Add it to my budget as a fixed weekly cost", "Treating it like a bill means it never catches you out.", reliability=15, balance=10, money=-20),
                    opt("Pay when I remember", "Paying late puts pressure on the people you live with, and it's a habit lenders notice later.", reliability=-15, money=-20),
                    opt("Ask to pay less this month and say why", "Talking early is much better than missing a payment.", reliability=5, wisdom=10, money=-10),
                    topic="sharing costs"),
                 ev("Bus fares go up by 50p a trip.",
                    opt("Work out the new monthly cost and adjust my budget", "Small price rises add up over a month, so updating your plan keeps it real.", wisdom=10, balance=10, money=-10),
                    opt("Ignore it", "50p a trip, twice a day, five days a week is about £20 a month.", balance=-10, money=-20),
                    opt("Check for a cheaper weekly or student ticket", "Capped and student tickets can save a lot. It's always worth checking.", wisdom=15, balance=5, money=-5),
                    topic="price rises"),
                 q("What's the simplest way to start a budget?",
                   opt("Write down the money coming in and going out", "That's it. Everything else builds on knowing your money in and out.", correct=True),
                   opt("Download five different apps", "Tools help, but the first step is just knowing what comes in and goes out.", correct=False),
                   opt("Wait until you earn more", "Starting now, with whatever you have, is what builds the habit.", correct=False),
                   topic="starting a budget"),
             ],
             "learned": ["Treat shared costs like bills.", "Small price rises add up: update your plan.", "A budget is money in vs money out."]},
            {"title": "Expect the unexpected", "persona": "Priya, 16, helps care for her mum and gets £20 a week from family.",
             "steps": [
                 ev("Your phone screen cracks. A repair shop quotes £60.",
                    opt("Check if any insurance or warranty covers it first", "Always check what cover you already have before paying.", wisdom=15, money=0),
                    opt("Ask for quotes and choose a cheaper, trusted repair", "Comparing prices is a simple way to save.", wisdom=10, balance=5, money=-40),
                    opt("Keep using it cracked for now", "That can be sensible if it still works safely, while you save up.", resilience=5, money=0),
                    topic="unexpected costs"),
                 q("What's an emergency fund?",
                   opt("Money set aside for surprises, like repairs", "Yes. Even a small fund means a surprise doesn't become a crisis.", correct=True),
                   opt("Money for a holiday", "That's a savings goal. An emergency fund is only for surprises.", correct=False),
                   opt("A loan you take when things go wrong", "A loan is borrowing. An emergency fund is your own money.", correct=False),
                   topic="emergency fund"),
                 tf("You need a big income to build an emergency fund.", False,
                    "False. Putting aside even £1 or £2 a week adds up, and it's the habit that counts.", topic="emergency fund"),
             ],
             "learned": ["Check existing cover before paying for repairs.", "An emergency fund is for surprises only.", "Any amount, saved regularly, builds a buffer."]},
        ],
    },
    {
        "id": 2, "title": "Payslips, tax and National Insurance", "symbol": "doc.text.fill",
        "summary": "Read your first payslip: gross, net, tax codes and NI.", "needsMoreContent": True,
        "levels": [
            {"title": "Your first payslip", "persona": "Kai, 17, has just started at a supermarket.",
             "steps": [
                 q("On a payslip, what does 'gross pay' mean?",
                   opt("Your pay before anything is taken off", "Right. Net pay is what lands in your account after deductions.", correct=True),
                   opt("Your pay after tax", "That's net pay. Gross is before deductions.", correct=False),
                   opt("Your overtime only", "Gross pay is all your pay before deductions.", correct=False), topic="gross and net pay"),
                 q("What does a tax code do?",
                   opt("Tells your employer how much tax-free pay you get", "{{fact:taxCode}} {{fact:personalAllowance}}", correct=True),
                   opt("It's your employee ID", "{{fact:taxCode}}", correct=False),
                   opt("It shows your bank details", "{{fact:taxCode}}", correct=False), topic="tax codes"),
                 ev("You're offered an extra shift during exam week.",
                    opt("Say no this time and ask for a shift next week", "Your exams matter too. Balancing work and study is a good money skill.", wisdom=10, endurance=5, money=0),
                    opt("Take it", "Fine if you can manage it. Extra pay helps, but not at any cost.", resilience=5, money=45),
                    topic="extra shifts"),
                 tf("Your National Insurance number usually arrives around your 16th birthday.", True, "{{fact:niNumber}}", topic="National Insurance"),
             ],
             "learned": ["Gross is before deductions; net is what you get.", "Check your tax code is right.", "Keep your NI number safe."]},
        ],
    },
    {
        "id": 3, "title": "Bank accounts", "symbol": "building.columns.fill",
        "summary": "Current vs savings accounts, debit cards, interest and AER.", "needsMoreContent": True,
        "levels": [
            {"title": "Two accounts", "persona": "Mina, 17, is an international student at a Manchester college.",
             "steps": [
                 q("What's a current account mainly for?",
                   opt("Everyday spending, with a debit card", "Yes. A savings account is for money you're putting aside.", correct=True),
                   opt("Earning the most interest", "Savings accounts usually pay more interest. Current accounts are for day-to-day money.", correct=False),
                   opt("Borrowing money", "A current account is for your own money. Borrowing is separate.", correct=False), topic="current accounts"),
                 q("What does AER tell you?",
                   opt("How much interest you'd earn over a year", "AER (annual equivalent rate) helps you compare savings accounts fairly.", correct=True),
                   opt("The cost of borrowing", "That's APR. AER is for savings.", correct=False),
                   opt("Your account number", "AER is an interest rate, used to compare savings accounts.", correct=False), topic="AER"),
                 ev("You can't find your debit card.",
                    opt("Freeze it in my banking app straight away", "Freezing is instant and you can unfreeze it if it turns up.", reliability=10, wisdom=10, money=0),
                    opt("Wait a few days to see if it turns up", "Someone could use it in the meantime. Freeze first, then look.", resilience=-10, money=0),
                    topic="lost cards"),
                 tf("Savings in UK banks have some protection if the bank fails.", True, "{{fact:savingsProtection}}", topic="savings protection"),
             ],
             "learned": ["Current account for spending, savings account for saving.", "Compare savings with AER.", "Freeze a lost card straight away."]},
        ],
    },
    {
        "id": 4, "title": "Saving and compound interest", "symbol": "chart.line.uptrend.xyaxis",
        "summary": "Why starting small and early works.", "needsMoreContent": True,
        "levels": [
            {"title": "Interest on interest", "persona": "Sam, 17, gets a college bursary instead of wages.",
             "steps": [
                 q("What is compound interest?",
                   opt("Interest earned on your savings and on interest you've already earned", "Yes. Over time it snowballs, which is why starting early helps.", correct=True),
                   opt("A fee for saving", "It's the opposite: money you earn on savings.", correct=False),
                   opt("Interest that's only paid once", "Compound interest keeps building on itself.", correct=False), topic="compound interest"),
                 ev("Your bursary payment arrives.",
                    opt("Move a small fixed amount to savings straight away", "Paying yourself first works whatever your income.", resilience=15, endurance=10, money=-10),
                    opt("Save whatever's left at the end of the month", "There often isn't anything left. Saving first is more reliable.", resilience=-5, money=0),
                    topic="saving first"),
                 tf("Saving £2 a week is too little to matter.", False, "False. £2 a week is over £100 a year, and the habit matters more than the amount.", topic="small savings"),
             ],
             "learned": ["Compound interest is interest on interest.", "Save first, spend after.", "Small regular amounts add up."]},
        ],
    },
    {
        "id": 5, "title": "Borrowing", "symbol": "creditcard.fill",
        "summary": "APR, overdrafts, buy now pay later, payday loans and the minimum-payment trap.", "needsMoreContent": False,
        "levels": [
            {"title": "What borrowing costs", "persona": "Jordan, 17, is thinking about the future.",
             "steps": [
                 q("What does APR show?",
                   opt("The yearly cost of borrowing, including interest and most fees", "APR lets you compare the cost of different credit. Higher APR means more expensive.", correct=True),
                   opt("How much you'll earn on savings", "That's AER. APR is the cost of borrowing.", correct=False),
                   opt("Your monthly pay", "APR is about borrowing, not pay.", correct=False), topic="APR"),
                 tf("An arranged overdraft is a type of borrowing.", True, "True. An overdraft lets you spend money you don't have, and you'll usually pay interest on it.", topic="overdrafts"),
                 ev("A friend says: 'Just borrow it, everyone does.'",
                    opt("Work out the total cost and whether I can repay it", "Knowing the full cost before you borrow is the most important borrowing skill.", wisdom=15, resilience=5, money=0),
                    opt("Borrow first and think later", "Borrowing without a plan to repay is how debt grows.", resilience=-15, reliability=-10, money=0),
                    opt("Wait and save up instead", "Often the cheapest option is not borrowing at all.", resilience=10, wisdom=10, money=0),
                    topic="deciding to borrow"),
             ],
             "learned": ["APR is the yearly cost of borrowing.", "Overdrafts are borrowing too.", "Know the total cost before you borrow."]},
            {"title": "Buy now pay later", "persona": "Ellie, 17, is buying trainers online.",
             "steps": [
                 ev("The checkout offers: 'Split £90 into 3 payments of £30!'",
                    opt("Check I can afford all 3 payments, or pay in one go if I have the money", "Splitting doesn't make something cheaper. Only use it if all the payments fit your budget.", wisdom=15, balance=5, money=-90),
                    opt("Split it, it feels cheaper", "It's the same £90. Several 'small' plans at once can add up fast.", balance=-15, money=-30),
                    opt("Save up and buy them next month", "Waiting costs nothing and avoids missed payments.", resilience=10, wisdom=5, money=0),
                    topic="buy now pay later"),
                 tf("Buy now pay later is still borrowing.", True, "{{fact:bnplCredit}}", topic="buy now pay later"),
                 q("You've got three buy now pay later plans running. What's the risk?",
                   opt("Payments can add up and be hard to keep track of", "Many small payments can take a big chunk of your money each month.", correct=True),
                   opt("None, they're interest-free", "Some are interest-free, but late fees and missed payments still cost you.", correct=False),
                   opt("You'll get a better credit score", "Missing payments can harm your credit file, not help it.", correct=False), topic="buy now pay later"),
             ],
             "learned": ["Splitting a payment doesn't make it cheaper.", "BNPL is borrowing with consequences if you miss payments.", "Keep track of every plan you're in."]},
            {"title": "Traps to avoid", "persona": "Marcus, 17, is leaving care and planning his first flat.",
             "steps": [
                 ev("Money is short a week before payday.",
                    opt("Talk to my key worker or a trusted adult about options", "Asking for help early is a strength. There may be support you didn't know about.", wisdom=15, resilience=10, money=0),
                    opt("Use my emergency fund for essentials only", "That's exactly what it's for. Top it up when you can.", resilience=5, money=-30),
                    opt("Take a payday loan", "Payday loans are a very expensive way to borrow. {{fact:paydayCap}}", resilience=-20, reliability=-10, money=50),
                    topic="payday loans"),
                 tf("Paying only the minimum on a credit card each month is the cheapest way to clear it.", False,
                    "False. Paying only the minimum means it takes much longer to clear and you pay much more interest. This is the minimum-payment trap.", topic="minimum payments"),
                 q("Which is usually the most expensive way to borrow?",
                   opt("A payday loan", "Yes. Payday loans usually cost far more than other borrowing.", correct=True),
                   opt("Borrowing from family, if agreed fairly", "Family loans can be interest-free, but agree a repayment plan.", correct=False),
                   opt("Not borrowing and waiting", "Waiting costs nothing.", correct=False), topic="payday loans"),
             ],
             "learned": ["Ask for help early when money's short.", "Payday loans are very expensive.", "Minimum payments keep you in debt longer."]},
        ],
    },
    {
        "id": 6, "title": "Credit files", "symbol": "doc.badge.clock.fill",
        "summary": "What's on a credit file, why it starts at 18, and why your Readiness Score isn't one.", "needsMoreContent": False,
        "levels": [
            {"title": "What's on a credit file?", "persona": "Zara, 17, wants to rent a flat one day.",
             "steps": [
                 q("Which of these is on a credit file?",
                   opt("Whether you've paid credit and some bills on time", "Yes. Payment history is a big part of a credit file.", correct=True),
                   opt("Your exam results", "Credit files are about borrowing and bills, not school.", correct=False),
                   opt("Every shop you've bought from", "Your everyday shopping isn't on your credit file.", correct=False),
                   opt("How much you have in savings", "Savings balances aren't on your credit file.", correct=False), topic="credit files"),
                 tf("Most credit files start around your 18th birthday.", True, "{{fact:creditFileAge}}", topic="credit file age"),
                 ev("You're 17 and want to be ready for your first account at 18.",
                    opt("Pay any bills I share on time, every time", "On-time habits now make it easy later.", reliability=15, endurance=5, money=0),
                    opt("Sign up for a credit card the day I turn 18", "There's no rush. Borrowing because you can isn't a plan.", wisdom=-5, resilience=-5, money=0),
                    opt("Learn what lenders look for", "Knowing what matters means no surprises.", wisdom=15, money=0),
                    topic="getting ready for 18"),
             ],
             "learned": ["Credit files show payment history.", "They usually start around 18.", "On-time habits matter more than anything."]},
            {"title": "Building a good record", "persona": "Leo, 17, shares a phone bill with his dad.",
             "steps": [
                 tf("Being on the electoral register can help lenders confirm who you are.", True, "{{fact:electoralRegister}}", topic="electoral register"),
                 ev("You forgot to send your share of the phone bill and it's 2 days late.",
                    opt("Pay now and set a reminder for next month", "Fixing it fast and setting a reminder stops it happening again.", reliability=10, wisdom=10, money=-10),
                    opt("Leave it until next month", "Late payments add up. On real credit, missed payments are recorded.", reliability=-20, money=0),
                    opt("Tell my dad and pay what I can now", "Talking early always helps.", reliability=5, wisdom=5, money=-5),
                    topic="late payments"),
                 q("How long do missed payments usually stay on a credit file?",
                   opt("About six years", "{{fact:missedPayments}}", correct=True),
                   opt("One month", "{{fact:missedPayments}}", correct=False),
                   opt("Until you turn 18", "{{fact:missedPayments}}", correct=False), topic="missed payments"),
             ],
             "learned": ["Register to vote when you can.", "Reminders beat late payments.", "Missed payments stay on a file for years."]},
            {"title": "Readiness vs credit score", "persona": "Amara, 16, is checking her Nova Readiness Score.",
             "steps": [
                 tf("Your Nova Readiness Score is your credit score.", False,
                    "False. It's a readiness score, not a credit score. It shows habits that matter later, but it isn't shared with credit reference agencies and doesn't change a credit file.", topic="Readiness Score"),
                 ev("Someone messages: 'Pay £50 and we'll fix your credit score.'",
                    opt("Ignore and block them", "Nobody can 'fix' a credit score for a fee. It's a scam.", wisdom=15, resilience=5, money=0),
                    opt("Pay, just in case", "This is a scam. You'd lose £50 and maybe your details.", resilience=-20, money=-50),
                    topic="credit repair scams"),
                 q("What helps a future credit file the most?",
                   opt("Paying on time, every time", "Yes. Payment history matters more than the amount you borrow or earn.", correct=True),
                   opt("Earning a lot", "Income isn't the main thing. Paying on time is.", correct=False),
                   opt("Borrowing as much as possible", "Borrowing more doesn't help. Managing it well does.", correct=False), topic="credit files"),
             ],
             "learned": ["The Readiness Score is not a credit score.", "Nobody can fix a credit score for a fee.", "On-time payments matter most."]},
        ],
    },
    {
        "id": 7, "title": "Scams and money mules", "symbol": "exclamationmark.shield.fill",
        "summary": "Spot 'easy money' offers, stay safe and know what to do.", "needsMoreContent": False,
        "levels": [
            {"title": "Easy money?", "persona": "Jay, 17, gets a DM on social media.",
             "steps": [
                 ev("A DM says: 'Earn £500 this week! Just let us send money through your bank account.'",
                    opt("Block, report and tell someone I trust", "This is how money mule recruiters work. Blocking and reporting is exactly right.", wisdom=20, resilience=10, money=0),
                    opt("Ask a few questions first", "There's no safe version of this offer. The safest thing is to stop replying.", wisdom=0, money=0),
                    opt("Say yes, it's only one week", "{{fact:moneyMule}}", resilience=-30, reliability=-20, money=0),
                    topic="money mules"),
                 q("What is a money mule?",
                   opt("Someone who lets their account be used to move other people's money", "{{fact:moneyMule}}", correct=True),
                   opt("A type of savings account", "{{fact:moneyMule}}", correct=False),
                   opt("A delivery job", "{{fact:moneyMule}}", correct=False), topic="money mules"),
                 tf("If you didn't know the money was stolen, there are no consequences.", False,
                    "False. You could still lose your bank account and find it hard to open one later. {{fact:moneyMule}}", topic="money mules"),
             ],
             "learned": ["'Easy money' for using your account is money muling.", "Block, report and tell someone you trust.", "It can close your bank account for years."]},
            {"title": "Spot the scam", "persona": "Noah, 16, gets a call from 'his bank'.",
             "steps": [
                 ev("A caller says they're from your bank and asks you to move your money to a 'safe account'.",
                    opt("Hang up and call my bank on a number I trust", "{{fact:fraudLine}}", wisdom=20, resilience=10, money=0),
                    opt("Do what they say, they know my name", "Scammers often know personal details. A real bank will never ask you to move money to keep it safe.", resilience=-30, money=-150),
                    topic="safe account scams"),
                 tf("Your bank will never ask for your full PIN or password.", True, "True. Never share your PIN, passwords or one-time codes with anyone, even someone who says they're from your bank.", topic="PINs and passwords"),
                 q("A text says your parcel is waiting and links to a site asking for card details. What's the red flag?",
                   opt("An unexpected link asking for card details", "Unexpected links and urgent requests are classic signs of a scam. Go to the company's app or website yourself.", correct=True),
                   opt("It mentions a parcel", "Parcels are normal. The red flag is a link asking for card details.", correct=False),
                   opt("It arrived by text", "Texts can be real, but links asking for card details are a warning sign.", correct=False), topic="phishing"),
             ],
             "learned": ["Banks never ask you to move money to a 'safe account'.", "Never share PINs, passwords or codes.", "Don't use links in unexpected messages."]},
            {"title": "If it happens to you", "persona": "Ruby, 16, thinks she gave her card details to a fake site.",
             "steps": [
                 ev("You realise you typed your card details into a fake website.",
                    opt("Contact my bank straight away and freeze my card", "{{fact:reportFraud}}", wisdom=15, resilience=15, money=0),
                    opt("Wait and see if anything happens", "Acting fast gives your bank the best chance to stop payments.", resilience=-20, money=-60),
                    topic="what to do after a scam"),
                 tf("It's best to keep quiet if you've been scammed, because it's embarrassing.", False,
                    "False. Scams fool people of every age. Telling your bank and a trusted adult quickly is the smart move.", topic="getting help"),
                 q("Who should you tell first?",
                   opt("My bank", "Yes. Your bank can freeze your card and look into payments. Then tell a trusted adult.", correct=True),
                   opt("Nobody", "Telling your bank quickly is the best way to protect your money.", correct=False),
                   opt("The website that scammed me", "Don't contact the scammers. Go to your bank.", correct=False), topic="getting help"),
             ],
             "learned": ["Act fast: call your bank and freeze your card.", "There's no shame in being scammed.", "Report it so others are protected too."]},
        ],
    },
    {
        "id": 8, "title": "Phone contracts, subscriptions and free trials", "symbol": "iphone.gen3",
        "summary": "Free trials that turn into payments, and what a contract means.", "needsMoreContent": True,
        "levels": [
            {"title": "Free for 30 days", "persona": "Freya, 17, signs up for a music trial.",
             "steps": [
                 ev("A free trial needs your card details and renews in 30 days.",
                    opt("Set a reminder to cancel before it renews", "Free trials are designed to roll into paid ones. A reminder keeps you in control.", wisdom=15, balance=5, money=0),
                    opt("Sign up and forget about it", "Forgotten subscriptions are one of the easiest ways to lose money.", balance=-10, money=-11),
                    topic="free trials"),
                 tf("A phone contract that includes a handset is usually a credit agreement.", True, "{{fact:phoneContract}}", topic="phone contracts"),
                 q("You have 4 subscriptions. What's a good habit?",
                   opt("Check them every few months and cancel ones I don't use", "Regular check-ups stop money leaking away.", correct=True),
                   opt("Keep them all, they're cheap", "Small amounts add up across a year.", correct=False), topic="subscriptions"),
             ],
             "learned": ["Set reminders before trials renew.", "Phone contracts with handsets are credit.", "Review subscriptions regularly."]},
        ],
    },
    {
        "id": 9, "title": "Moving out", "symbol": "house.fill",
        "summary": "Rent, deposits, bills and council tax.", "needsMoreContent": True,
        "levels": [
            {"title": "Your first place", "persona": "Ben, 17, is a care leaver planning his first flat with support.",
             "steps": [
                 q("Besides rent, which costs should you plan for?",
                   opt("Energy, water, internet, council tax and a deposit", "Yes. Rent is only part of the cost of a home.", correct=True),
                   opt("Just rent", "Bills and a deposit can add a lot. Plan for them too.", correct=False), topic="moving out costs"),
                 tf("A tenancy deposit has to be protected in an approved scheme in England and Wales.", True, "{{fact:depositProtection}}", topic="deposits"),
                 ev("You're not sure whether you have to pay council tax.",
                    opt("Check with the council or a support worker", "{{fact:councilTax}}", wisdom=15, money=0),
                    opt("Assume I don't and ignore letters", "Ignoring council tax letters can lead to bigger bills. Always check.", reliability=-15, money=0),
                    topic="council tax"),
             ],
             "learned": ["Rent is only part of the cost of a home.", "Deposits should be protected.", "Check council tax rather than guess."]},
        ],
    },
    {
        "id": 10, "title": "When money is tight", "symbol": "lifepreserver.fill",
        "summary": "Social tariffs, benefits checkers, free debt advice and talking to your bank.", "needsMoreContent": True,
        "levels": [
            {"title": "Where to get help", "persona": "Mo, 17, whose family's income has dropped.",
             "steps": [
                 tf("Some broadband and mobile companies offer cheaper deals to people on certain benefits.", True, "{{fact:socialTariffs}}", topic="social tariffs"),
                 q("Where can you get free debt advice?",
                   opt("Free debt advice charities", "{{fact:debtAdvice}}", correct=True),
                   opt("A company that charges a big fee", "You never need to pay for good debt advice.", correct=False),
                   opt("Nowhere, you have to sort it alone", "You don't. Free help exists.", correct=False), topic="debt advice"),
                 ev("Money is tight this month.",
                    opt("Talk to my bank or a trusted adult early", "Banks have teams to help, and talking early gives you more options.", wisdom=15, resilience=10, money=0),
                    opt("Use a free benefits calculator with my family", "{{fact:benefitsCheck}}", wisdom=15, money=0),
                    opt("Hide it and hope it gets better", "Problems usually grow when hidden. Asking for help is a strength.", resilience=-15, money=0),
                    topic="getting help early"),
             ],
             "learned": ["Social tariffs can cut bills.", "Debt advice is free.", "Talk early: there are more options."]},
        ],
    },
]


def main():
    for chapter in CHAPTERS:
        for li, level in enumerate(chapter["levels"], start=1):
            level["id"] = f"c{chapter['id']}l{li}"
            for si, step in enumerate(level["steps"], start=1):
                step["id"] = f"{level['id']}s{si}"
    content = {
        "version": 1,
        "facts": [
            {"id": fid, "text": text, "source": source, "verifyBeforeDemo": True, "year": 2026}
            for fid, text, source in FACTS
        ],
        "chapters": CHAPTERS,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(content, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    levels = sum(len(c["levels"]) for c in CHAPTERS)
    print(f"Wrote {OUT} ({len(CHAPTERS)} chapters, {levels} levels, {len(FACTS)} facts)")


if __name__ == "__main__":
    main()
